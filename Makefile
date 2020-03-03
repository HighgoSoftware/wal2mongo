# contrib/wal2mongo/Makefile

MODULES = wal2mongo
PGFILEDESC = "wal2mongo - a logical decoding output plugin for MongoDB"

REGRESS = ddl xact rewrite toast permissions decoding_in_xact \
	decoding_into_rel binary prepared replorigin time messages \
	spill slot truncate
ISOLATION = mxact delayed_startup ondisk_startup concurrent_ddl_dml \
	oldest_xmin snapshot_transfer

REGRESS_OPTS = --temp-config $(top_srcdir)/contrib/wal2mongo/logical.conf
ISOLATION_OPTS = --temp-config $(top_srcdir)/contrib/wal2mongo/logical.conf

# Disabled because these tests require "wal_level=logical", which
# typical installcheck users do not have (e.g. buildfarm clients).
NO_INSTALLCHECK = 1

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/wal2mongo
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

# But it can nonetheless be very helpful to run tests on preexisting
# installation, allow to do so, but only if requested explicitly.
installcheck-force:
	$(pg_regress_installcheck) $(REGRESS)
	$(pg_isolation_regress_installcheck) $(ISOLATION)