# Build the entity AgentX subagent against a sibling net-snmp source tree.
# Run from this directory:
#   make          # dynamically linked (default)
#   make static   # statically linked, portable binary
#
# Expects ../net-snmp to be a configured and built net-snmp tree.

HERE    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SRCDIR  := $(realpath $(HERE)../net-snmp)

CFLAGS  := -g -Wall \
           -I$(SRCDIR)/include \
           -I$(SRCDIR) \
           -DHAVE_CONFIG_H

# Shared-library build flags
LDFLAGS_SHARED := \
    -L$(SRCDIR)/agent/.libs \
    -L$(SRCDIR)/snmplib/.libs \
    -lnetsnmpmibs \
    -lnetsnmpagent \
    -lnetsnmp \
    -Wl,-rpath,$(SRCDIR)/agent/.libs \
    -Wl,-rpath,$(SRCDIR)/snmplib/.libs \
    -lm -lssl -lcrypto -lpci -lnl-route-3 -lnl-3 -lsensors

# Static build: pull the net-snmp .a archives directly; everything else static too
LDFLAGS_STATIC := \
    -Wl,-Bstatic \
    $(SRCDIR)/agent/.libs/libnetsnmpmibs.a \
    $(SRCDIR)/agent/.libs/libnetsnmpagent.a \
    $(SRCDIR)/snmplib/.libs/libnetsnmp.a \
    -Wl,-Bdynamic \
    -lm -lssl -lcrypto -lpci -lnl-route-3 -lnl-3 -lsensors -lperl

# Object files from the already-built entity module
ENTITY_OBJS := \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entity.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entPhysicalTable.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entAliasMappingTable.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entLastChangeTime.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entLogicalTable.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/data_access/entity_linux.o

entity_subagent: entity_subagent.o $(ENTITY_OBJS)
	$(CC) -o $@ $^ $(LDFLAGS_SHARED)

static: entity_subagent.o $(ENTITY_OBJS)
	$(CC) -o entity_subagent $^ $(LDFLAGS_STATIC)

entity_subagent.o: entity_subagent.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f entity_subagent entity_subagent.o

.PHONY: clean static
