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

#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/rel.h"

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
	bool		include_xids;
	bool		include_timestamp;
	bool		skip_empty_xacts;
	bool		xact_wrote_changes;
	bool		only_local;
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
	data->include_xids = true;
	data->include_timestamp = false;
	data->skip_empty_xacts = false;
	data->only_local = false;

	ctx->output_plugin_private = data;

	opt->output_type = OUTPUT_PLUGIN_TEXTUAL_OUTPUT;
	opt->receive_rewrites = false;

	foreach(option, ctx->output_plugin_options)
	{

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

}

/* COMMIT callback */
static void
pg_w2m_decode_commit_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn,
					 	 XLogRecPtr commit_lsn)
{

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
		if ( natt == 0 )
			appendStringInfoString(s, " \{ ");
		else
			appendStringInfoString(s, ", ");

		appendStringInfoString(s, quote_identifier(NameStr(attr->attname)));

		/* query output function */
		getTypeOutputInfo(typid,
						  &typoutput, &typisvarlena);

		/* print separator */
		appendStringInfoChar(s, ':');

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
		if ( natt == tupdesc->natts -1 )
			appendStringInfoString(s, " } )");
	}
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
									false);
			break;
		case REORDER_BUFFER_CHANGE_UPDATE:
			appendStringInfoString(ctx->out, " UPDATE:");
			if (change->data.tp.oldtuple != NULL)
			{
				appendStringInfoString(ctx->out, " old-key:");
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.oldtuple->tuple,
									true);
				appendStringInfoString(ctx->out, " new-tuple:");
			}

			if (change->data.tp.newtuple == NULL)
				appendStringInfoString(ctx->out, " (no-tuple-data)");
			else
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.newtuple->tuple,
									false);
			break;
		case REORDER_BUFFER_CHANGE_DELETE:
			appendStringInfoString(ctx->out, " DELETE:");

			/* if there was no PK, we only know that a delete happened */
			if (change->data.tp.oldtuple == NULL)
				appendStringInfoString(ctx->out, " (no-tuple-data)");
			/* In DELETE, only the replica identity is present; display that */
			else
				tuple_to_stringinfo(ctx->out, tupdesc,
									&change->data.tp.oldtuple->tuple,
									true);
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
