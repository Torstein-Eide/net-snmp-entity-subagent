# Build the entity AgentX subagent against a sibling net-snmp source tree.
# Run from this directory:
#   make                                          # static (default)
#   make shared                                   # dynamically linked
#   make CC=arm-linux-gnueabihf-gcc               # cross-compile
#   make OUTPUT=entity_subagent-arm               # custom output name
#
# Expects ../net-snmp to be a configured and built net-snmp tree.

HERE    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SRCDIR  := $(realpath $(HERE)../net-snmp)
OUTPUT  ?= entity_subagent

CPPFLAGS := \
    -I$(SRCDIR)/include \
    -I$(SRCDIR) \
    -DHAVE_CONFIG_H

CFLAGS  += -g -Wall -MMD -MP

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

# Object files from the entity module (rebuilt via the net-snmp Makefile when stale)
ENTITY_OBJS := \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entity.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entPhysicalTable.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entAliasMappingTable.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entLastChangeTime.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/entLogicalTable.o \
    $(SRCDIR)/agent/mibgroup/hardware/entity/data_access/entity_linux.o

# Central header — all entity .o files must be rebuilt when it changes
ENTITY_H := $(SRCDIR)/agent/mibgroup/hardware/entity/entity.h

all: static

static: entity_subagent.o $(ENTITY_OBJS)
	$(CC) -o $(OUTPUT) $^ $(LDFLAGS_STATIC)

shared: entity_subagent.o $(ENTITY_OBJS)
	$(CC) -o $(OUTPUT) $^ $(LDFLAGS_SHARED)

entity_subagent.o: entity_subagent.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

# Rebuild each entity .o via the net-snmp Makefile when its source or entity.h changes
$(ENTITY_OBJS): %.o: %.c $(ENTITY_H)
	$(MAKE) -C $(SRCDIR) $(@:$(SRCDIR)/%=%)

clean:
	rm -f $(OUTPUT) entity_subagent.o entity_subagent.d

-include entity_subagent.d

.PHONY: all static shared clean
