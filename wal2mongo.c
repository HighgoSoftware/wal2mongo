/*-------------------------------------------------------------------------
 *
 * wal2mongo.c
 *		logical decoding output plugin for MongoDB
 *
 * Copyright (c) 2019-2020, Highgo Global Development Center
 *
 * IDENTIFICATION
 * 		when build under PostgreSQL source code tree,
 *			contrib/wal2mongo/wal2mongo.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "catalog/pg_type.h"

#include "replication/logical.h"
#include "replication/origin.h"
#include "commands/dbcommands.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/rel.h"
#include "utils/guc.h"

PG_MODULE_MAGIC;

/* These must be available to pg_dlsym() */
extern void _PG_init(void);
extern void _PG_output_plugin_init(OutputPluginCallbacks *cb);

typedef struct
{
	bool 		insert;
	bool		update;
	bool		delete;
	bool		truncate;
} Wal2MongoAction;

typedef struct
{
	MemoryContext context;
	bool		include_timestamp;
	bool		skip_empty_xacts;
	bool		xact_wrote_changes;
	bool		only_local;
	bool 		use_transaction;
	bool		include_cluster_name;
	bool		regress;
	Wal2MongoAction	actions;
} Wal2MongoData;

static void pg_w2m_decode_startup(LogicalDecodingContext *ctx,
								  OutputPluginOptions *opt,
							  	  bool is_init);

static void pg_w2m_decode_shutdown(LogicalDecodingContext *ctx);

static void pg_w2m_decode_begin_txn(LogicalDecodingContext *ctx,
									ReorderBufferTXN *txn);

static void pg_w2m_decode_commit_txn(LogicalDecodingContext *ctx,
								 	 ReorderBufferTXN *txn, XLogRecPtr commit_lsn);

static void pg_w2m_decode_change(LogicalDecodingContext *ctx,
							 	 ReorderBufferTXN *txn, Relation rel,
								 ReorderBufferChange *change);

static void pg_w2m_decode_truncate(LogicalDecodingContext *ctx,
							   	   ReorderBufferTXN *txn,
								   int nrelations, Relation relations[],
								   ReorderBufferChange *change);

static bool pg_w2m_decode_filter(LogicalDecodingContext *ctx,
							 	 RepOriginId origin_id);

static void pg_w2m_decode_message(LogicalDecodingContext *ctx,
							  	  ReorderBufferTXN *txn, XLogRecPtr message_lsn,
								  bool transactional, const char *prefix,
								  Size sz, const char *message);

static bool split_string_to_list(char *rawstring, char separator, List **sl);


/* Will be called immediately after loaded */
void
_PG_init(void)
{

}

/* Initialize callback functions */
void
_PG_output_plugin_init(OutputPluginCallbacks *cb)
{
	AssertVariableIsOfType(&_PG_output_plugin_init, LogicalOutputPluginInit);

	cb->startup_cb = pg_w2m_decode_startup;
	cb->begin_cb = pg_w2m_decode_begin_txn;
	cb->change_cb = pg_w2m_decode_change;
	cb->truncate_cb = pg_w2m_decode_truncate;
	cb->commit_cb = pg_w2m_decode_commit_txn;
	cb->filter_by_origin_cb = pg_w2m_decode_filter;
	cb->shutdown_cb = pg_w2m_decode_shutdown;
	cb->message_cb = pg_w2m_decode_message;
}


/* Initialize this plugin's resources */
static void
pg_w2m_decode_startup(LogicalDecodingContext *ctx, OutputPluginOptions *opt,
				  	  bool is_init)
{
	ListCell   *option;
	Wal2MongoData *data;

	data = palloc0(sizeof(Wal2MongoData));
	data->context = AllocSetContextCreate(ctx->context,
										  "wal2mongo context",
										  ALLOCSET_DEFAULT_SIZES);
	data->include_timestamp = false;
	data->skip_empty_xacts = false;
	data->only_local = false;
	data->use_transaction = false;
	data->include_cluster_name = true;
	data->regress = false;

	data->actions.delete = true;
	data->actions.insert = true;
	data->actions.update = true;
	data->actions.truncate = true;

	ctx->output_plugin_private = data;

	opt->output_type = OUTPUT_PLUGIN_TEXTUAL_OUTPUT;
	opt->receive_rewrites = false;

	foreach(option, ctx->output_plugin_options)
	{
		DefElem *elem = lfirst(option);
		Assert(elem->arg == NULL || IsA(elem->arg, String));
		if (strcmp(elem->defname, "include_timestamp") == 0)
		{
			/* if option value is NULL then assume that value is false */
			if (elem->arg == NULL)
				data->include_timestamp = false;
			else if (!parse_bool(strVal(elem->arg), &data->include_timestamp))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
							 strVal(elem->arg), elem->defname)));
		}
		else if (strcmp(elem->defname, "skip_empty_xacts") == 0)
		{
			/* if option value is NULL then assume that value is false */
			if (elem->arg == NULL)
				data->skip_empty_xacts = false;
			else if (!parse_bool(strVal(elem->arg), &data->skip_empty_xacts))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
							 strVal(elem->arg), elem->defname)));
		}
		else if (strcmp(elem->defname, "only_local") == 0)
		{
			/* if option value is NULL then assume that value is false */
			if (elem->arg == NULL)
				data->only_local = false;
			else if (!parse_bool(strVal(elem->arg), &data->only_local))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
							 strVal(elem->arg), elem->defname)));
		}
		else if (strcmp(elem->defname, "use_transaction") == 0)
		{
			/* if option value is NULL then assume that value is false */
			if (elem->arg == NULL)
				data->use_transaction = false;
			else if (!parse_bool(strVal(elem->arg), &data->use_transaction))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
							 strVal(elem->arg), elem->defname)));
		}
		else if (strcmp(elem->defname, "force_binary") == 0)
		{
			bool		force_binary;

			if (elem->arg == NULL)
				continue;
			else if (!parse_bool(strVal(elem->arg), &force_binary))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
								strVal(elem->arg), elem->defname)));

			if (force_binary)
				opt->output_type = OUTPUT_PLUGIN_BINARY_OUTPUT;
		}
		else if (strcmp(elem->defname, "include_cluster_name") == 0)
		{
			/* if option value is NULL then assume that value is false */
			if (elem->arg == NULL)
				data->include_cluster_name = false;
			else if (!parse_bool(strVal(elem->arg), &data->include_cluster_name))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
							 strVal(elem->arg), elem->defname)));
		}
		else if (strcmp(elem->defname, "regress") == 0)
		{
			/* if option value is NULL then assume that value is false */
			if (elem->arg == NULL)
				data->regress = false;
			else if (!parse_bool(strVal(elem->arg), &data->regress))
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("could not parse value \"%s\" for parameter \"%s\"",
							 strVal(elem->arg), elem->defname)));
		}
		else if (strcmp(elem->defname, "actions") == 0)
		{
			char	*rawstr;

			if (elem->arg == NULL)
			{
				elog(DEBUG1, "actions argument is null");
				/* argument null means default; nothing to do here */
			}
			else
			{
				List		*selected_actions = NIL;
				ListCell	*lc;

				rawstr = pstrdup(strVal(elem->arg));
				if (!split_string_to_list(rawstr, ',', &selected_actions))
				{
					pfree(rawstr);
					ereport(ERROR,
							(errcode(ERRCODE_INVALID_NAME),
							 errmsg("could not parse value \"%s\" for parameter \"%s\"",
								 strVal(elem->arg), elem->defname)));
				}

				data->actions.insert = false;
				data->actions.update = false;
				data->actions.delete = false;
				data->actions.truncate = false;

				foreach(lc, selected_actions)
				{
					char *p = lfirst(lc);

					if (strcmp(p, "insert") == 0)
						data->actions.insert = true;
					else if (strcmp(p, "update") == 0)
						data->actions.update = true;
					else if (strcmp(p, "delete") == 0)
						data->actions.delete = true;
					else if (strcmp(p, "truncate") == 0)
						data->actions.truncate = true;
					else
						ereport(ERROR,
								(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
								 errmsg("could not parse value \"%s\" for parameter \"%s\"",
									 p, elem->defname)));
				}

				pfree(rawstr);
				list_free(selected_actions);
			}
		}
		else
		{
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("option \"%s\" = \"%s\" is unknown",
							elem->defname,
							elem->arg ? strVal(elem->arg) : "(null)")));
		}
	}
}

/* Cleanup this plugin's resources */
static void
pg_w2m_decode_shutdown(LogicalDecodingContext *ctx)
{
	Wal2MongoData *data = ctx->output_plugin_private;

	/* cleanup our own resources via memory context reset */
	MemoryContextDelete(data->context);
}

/* BEGIN callback */
static void
pg_w2m_decode_begin_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn)
{
	Wal2MongoData *data = ctx->output_plugin_private;

	/* Skip this callback if transaction mode is not enabled */
	if(!data->use_transaction)
		return;

	/* first write the session variable for Mongo */
	OutputPluginPrepareWrite(ctx, false);
	appendStringInfo(ctx->out, "session%u%s = db.getMongo().startSession();",
			data->regress == true? 0 : txn->xid, ctx->slot->data.name.data);
	OutputPluginWrite(ctx, false);

	/* then write transaction start */
	OutputPluginPrepareWrite(ctx, true);
	appendStringInfo(ctx->out, "session%u%s.startTransaction();",
			data->regress == true? 0 : txn->xid, ctx->slot->data.name.data);
	OutputPluginWrite(ctx, true);
}

/* COMMIT callback */
static void
pg_w2m_decode_commit_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn,
					 	 XLogRecPtr commit_lsn)
{
	Wal2MongoData *data = ctx->output_plugin_private;

	/* Skip this callback if transaction mode is not enabled */
	if(!data->use_transaction)
		return;

	/* first write the commit transaction cmd */
	OutputPluginPrepareWrite(ctx, false);
	appendStringInfo(ctx->out, "session%u%s.commitTransaction();",
			data->regress == true? 0 : txn->xid, ctx->slot->data.name.data);
	OutputPluginWrite(ctx, false);

	/* then write session termination */
	OutputPluginPrepareWrite(ctx, true);
	appendStringInfo(ctx->out, "session%u%s.endSession();",
			data->regress == true? 0 : txn->xid, ctx->slot->data.name.data);
	OutputPluginWrite(ctx, true);
}

/* Generic message callback */
static bool
pg_w2m_decode_filter(LogicalDecodingContext *ctx,
				 	 RepOriginId origin_id)
{
	return false;
}

/* PG to MG data conversion */
static void
print_w2m_literal(StringInfo s, Oid typid, char *outputstr)
{
	const char *valptr;

	switch (typid)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
			/* NB: We don't care about Inf, NaN et al. */
			appendStringInfoString(s, outputstr);
			break;

		case BITOID:
		case VARBITOID:
			appendStringInfo(s, "B'%s'", outputstr);
			break;

		case BOOLOID:
			if (strcmp(outputstr, "t") == 0)
				appendStringInfoString(s, "true");
			else
				appendStringInfoString(s, "false");
			break;

		default:
			appendStringInfoChar(s, '\"');
			for (valptr = outputstr; *valptr; valptr++)
			{
				char		ch = *valptr;

				if (SQL_STR_DOUBLE(ch, false))
					appendStringInfoChar(s, ch);
				appendStringInfoChar(s, ch);
			}
			appendStringInfoChar(s, '\"');
			break;
	}
}

/* print the tuple 'tuple' into the StringInfo s */
static void
tuple_to_stringinfo(StringInfo s, TupleDesc tupdesc, HeapTuple tuple, bool skip_nulls)
{
	int			natt;

	appendStringInfoString(s, " \{ ");
	/* print all columns individually */
	for (natt = 0; natt < tupdesc->natts; natt++)
	{
		Form_pg_attribute attr; /* the attribute itself */
		Oid			typid;		/* type of current attribute */
		Oid			typoutput;	/* output function */
		bool		typisvarlena;
		Datum		origval;	/* possibly toasted Datum */
		bool		isnull;		/* column is null? */

		attr = TupleDescAttr(tupdesc, natt);

		/*
		 * don't print dropped columns, we can't be sure everything is
		 * available for them
		 */
		if (attr->attisdropped)
			continue;

		/*
		 * Don't print system columns, oid will already have been printed if
		 * present.
		 */
		if (attr->attnum < 0)
			continue;

		typid = attr->atttypid;

		/* get Datum from tuple */
		origval = heap_getattr(tuple, natt + 1, tupdesc, &isnull);

		if (isnull && skip_nulls)
			continue;

		/* print attribute name */
		if ( natt != 0 )
			appendStringInfoString(s, ", ");

		appendStringInfoString(s, quote_identifier(NameStr(attr->attname)));

		/* print separator */
		appendStringInfoChar(s, ':');

		/* query output function */
		getTypeOutputInfo(typid,
						  &typoutput, &typisvarlena);

		/* print data */
		if (isnull)
			appendStringInfoString(s, "null");
		else if (typisvarlena && VARATT_IS_EXTERNAL_ONDISK(origval))
			appendStringInfoString(s, "unchanged-toast-datum");
		else if (!typisvarlena)
			print_w2m_literal(s, typid,
						  OidOutputFunctionCall(typoutput, origval));
		else
		{
			Datum		val;	/* definitely detoasted Datum */

			val = PointerGetDatum(PG_DETOAST_DATUM(origval));
			print_w2m_literal(s, typid, OidOutputFunctionCall(typoutput, val));
		}
	}
	appendStringInfoString(s, " }");
}

/*
 * callback for individual changed tuples
 */
static void
pg_w2m_decode_change(LogicalDecodingContext *ctx, ReorderBufferTXN *txn,
				 	 Relation relation, ReorderBufferChange *change)
{
	Wal2MongoData *data;
	Form_pg_class class_form;
	TupleDesc	tupdesc;
	MemoryContext old;

	data = ctx->output_plugin_private;

	data->xact_wrote_changes = true;

	class_form = RelationGetForm(relation);
	tupdesc = RelationGetDescr(relation);

	/* Avoid leaking memory by using and resetting our own context */
	old = MemoryContextSwitchTo(data->context);

	/* write the db switch command */
	OutputPluginPrepareWrite(ctx, false);

	/* Here we are concatenating ClusterName, DatabaseName, and SlotName to form
	 * a unified database name in MongoDB's perspective, so Mongo knows the changes
	 * are streamed from which cluster, which database and via which slot
	 *
	 * TODO: we will introduce more configurable options to fine-tune this output style
	 * behaviors.
	 */
	if(data->include_cluster_name)
	{
		appendStringInfo(ctx->out, "use %s_%s_%s;",
						data->regress == true ? "mycluster" :
								(cluster_name == NULL ? "mycluster" : cluster_name),
						get_database_name(relation->rd_node.dbNode),
						ctx->slot->data.name.data[0] == '\0' ? "myslot" : ctx->slot->data.name.data);
	}
	else
	{
		appendStringInfo(ctx->out, "use %s_%s;",
						get_database_name(relation->rd_node.dbNode),
						ctx->slot->data.name.data[0] == '\0' ? "myslot" : ctx->slot->data.name.data);
	}
	OutputPluginWrite(ctx, false);

	OutputPluginPrepareWrite(ctx, true);
	appendStringInfoString(ctx->out,
						   quote_qualified_identifier("db", class_form->relrewrite ?
													  get_rel_name(class_form->relrewrite) :
													  NameStr(class_form->relname)));
	switch (change->action)
	{
		case REORDER_BUFFER_CHANGE_INSERT:
			appendStringInfoString(ctx->out, ".insertOne(");
			if (change->data.tp.newtuple == NULL)
				appendStringInfoString(ctx->out, " (no-tuple-data)");
			else
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.newtuple->tuple,
									true);
			appendStringInfoString(ctx->out, " );");
			break;
		case REORDER_BUFFER_CHANGE_UPDATE:
			appendStringInfoString(ctx->out, ".updateOne(");
			if (change->data.tp.oldtuple != NULL)
			{
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.oldtuple->tuple,
									true);
			}

			if (change->data.tp.newtuple != NULL)
			{
				appendStringInfoString(ctx->out, ", \{ $set: ");
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.newtuple->tuple,
									false);
				appendStringInfoString(ctx->out, " }");
			}
			appendStringInfoString(ctx->out, " );");
			break;
		case REORDER_BUFFER_CHANGE_DELETE:
			appendStringInfoString(ctx->out, ".deleteOne(");
			/* if there was no PK, we only know that a delete happened */
			if (change->data.tp.oldtuple == NULL)
				appendStringInfoString(ctx->out, " (no-tuple-data)");
			/* In DELETE, only the replica identity is present; display that */
			else
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.oldtuple->tuple,
									true);
			appendStringInfoString(ctx->out, " );");
			break;
		default:
			Assert(false);
	}

	MemoryContextSwitchTo(old);
	MemoryContextReset(data->context);

	OutputPluginWrite(ctx, true);
}

static void
pg_w2m_decode_truncate(LogicalDecodingContext *ctx, ReorderBufferTXN *txn,
				   	   int nrelations, Relation relations[], ReorderBufferChange *change)
{

}

static void
pg_w2m_decode_message(LogicalDecodingContext *ctx,
				  	  ReorderBufferTXN *txn, XLogRecPtr lsn, bool transactional,
					  const char *prefix, Size sz, const char *message)
{

}

static bool
split_string_to_list(char *rawstring, char separator, List **sl)
{
	char	   *nextp;
	bool		done = false;

	nextp = rawstring;

	while (isspace(*nextp))
		nextp++;				/* skip leading whitespace */

	if (*nextp == '\0')
		return true;			/* allow empty string */

	/* At the top of the loop, we are at start of a new identifier. */
	do
	{
		char	   *curname;
		char	   *endp;
		char	   *pname;

		curname = nextp;
		while (*nextp && *nextp != separator && !isspace(*nextp))
		{
			if (*nextp == '\\')
				nextp++;	/* ignore next character because of escape */
			nextp++;
		}
		endp = nextp;
		if (curname == nextp)
			return false;	/* empty unquoted name not allowed */

		while (isspace(*nextp))
			nextp++;			/* skip trailing whitespace */

		if (*nextp == separator)
		{
			nextp++;
			while (isspace(*nextp))
				nextp++;		/* skip leading whitespace for next */
			/* we expect another name, so done remains false */
		}
		else if (*nextp == '\0')
			done = true;
		else
			return false;		/* invalid syntax */

		/* Now safe to overwrite separator with a null */
		*endp = '\0';

		/*
		 * Finished isolating current name --- add it to list
		 */
		pname = pstrdup(curname);
		*sl = lappend(*sl, pname);

		/* Loop back if we didn't reach end of string */
	} while (!done);

	return true;
}
