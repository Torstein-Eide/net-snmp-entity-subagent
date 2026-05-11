# entity_subagent — AgentX subagent for ENTITY-MIB

A standalone AgentX subagent that registers the ENTITY-MIB subtree
(`1.3.6.1.2.1.47`) with any master snmpd, including older versions that do
not have the entity module built in.

## How it works

AgentX (RFC 2741) lets a separate process extend an SNMP agent by registering
MIB subtrees with a master agent over a local socket. The master proxies
incoming requests for those OIDs to the subagent transparently. The master
does not need to know anything about ENTITY-MIB — it just needs AgentX
enabled.

## Build

Build from the top of the net-snmp source tree after running `make`.

**Dynamic build** (requires net-snmp libs on the target machine):
```sh
make -f entity_subagent.mk
```

**Static build** (portable — net-snmp libs bundled into the binary):
```sh
make -f entity_subagent.mk static
```

Use the static build when deploying to a machine that does not have net-snmp
installed. The binary still depends on standard system libraries (`libssl`,
`libcrypto`, `libpci`, `libnl-3`) that are present on any modern Linux.

## Master agent setup

Add to the master snmpd's `snmpd.conf`:

```
master agentx
agentxsocket /var/agentx/master   # default path; omit to use default
```

Restart or send SIGHUP to the master.

## Running the subagent

```sh
./entity_subagent
```

sudo cp entity_subagent /usr/local/lib/snmpd/entity_subagent
sudo cp entity_subagent.service /etc/systemd/system/
sudo systemctl daemon-reload

sudo systemctl enable --now entity_subagent.service


The subagent connects to `/var/agentx/master` by default. To use a different
socket path:

```sh
./entity_subagent -x /path/to/agentx.sock
```

The subagent will reconnect automatically if the master restarts.

## Verifying

```sh
snmpwalk -v2c -c public localhost 1.3.6.1.2.1.47   # full ENTITY-MIB
snmpwalk -v2c -c public localhost ENTITY-MIB::entPhysicalTable
snmpget  -v2c -c public localhost ENTITY-MIB::entLastChangeTime.0
```

## Files

| File | Purpose |
|------|---------|
| `entity_subagent.c` | Subagent main; sets AgentX role, calls `init_entity()` |
| `entity_subagent.mk` | Standalone Makefile; links local `.o` files + shared libs |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error while loading shared libraries: libnetsnmpagent.so…` | net-snmp not installed on target | Use `make -f entity_subagent.mk static` and redeploy |
| `Failed to connect to the agentx master` | Master not running or wrong socket path | Start master first; check `agentxsocket` in snmpd.conf |
| `read_config_store open failure on /var/net-snmp/…` | State directory not writable | `mkdir -p /var/net-snmp && chown $USER /var/net-snmp` or run as root |
| Walk returns nothing for `1.3.6.1.2.1.47` | Registration not complete | Give the subagent a second after startup before walking |
| Duplicate OID errors in master log | Another agent also registered entity | Disable entity in the master's `--with-mib-modules` |
