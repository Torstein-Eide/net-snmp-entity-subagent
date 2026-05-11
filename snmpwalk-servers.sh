#!/bin/bash

#OPT="--show-parent-rel-pos"
OPT="--parent-rel-pos-tree"
for DEV in pve1 pve2; do
 echo "== $DEV"
 snmpwalk -v2c -c eide ${DEV}.internal .1.3.6.1.2.1.47  > ../net-snmp/.tmp/output/${DEV}.snmp.raw
 ./local/entphysical-tree.py  "$OPT" .tmp/output/${DEV}.snmp.raw   > ../net-snmp/.tmp/output/${DEV}.tree
done
