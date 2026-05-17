# net-snmp-entity-subagent - AgentX subagent for ENTITY-MIB

`net-snmp-entity-subagent` builds a small standalone AgentX subagent executable
named `entity_subagent`. It provides the
ENTITY-MIB SNMP tree:

```text
1.3.6.1.2.1.47
```

Use it when your existing `snmpd` master agent does not include ENTITY-MIB, or
when you want ENTITY-MIB served by a separate process.

This guide assumes you are starting from a fresh Linux machine with no project
files already installed.

## What You Need

You need two source folders next to each other:

```text
gitwork/
  net-snmp-entity-subagent/
  net-snmp/
```

The `net-snmp-entity-subagent` Makefile builds against `../net-snmp`, so this
folder layout matters.

You also need a working C build environment, `snmpd`, and the libraries used by
net-snmp.

## 1. Install System Packages

On Debian or Ubuntu:

```sh
sudo apt update
sudo apt install -y \
  build-essential \
  git \
  autoconf \
  automake \
  libtool \
  pkg-config \
  snmp \
  snmpd \
  libssl-dev \
  libpci-dev \
  libnl-3-dev \
  libnl-route-3-dev \
  libsensors-dev \
  libperl-dev
```

On Fedora, Rocky Linux, AlmaLinux, or RHEL-like systems, install the equivalent
packages with your system package manager. The package names are usually similar
to:

```sh
sudo dnf install -y \
  gcc \
  gcc-c++ \
  make \
  git \
  autoconf \
  automake \
  libtool \
  pkgconf-pkg-config \
  net-snmp \
  net-snmp-utils \
  net-snmp-agent-libs \
  openssl-devel \
  pciutils-devel \
  libnl3-devel \
  lm_sensors-devel \
  perl-devel
```

## 2. Create a Work Folder

Choose a place to keep the two source trees. This example uses `~/gitwork`:

```sh
mkdir -p ~/gitwork
cd ~/gitwork
```

## 3. Download net-snmp

Clone the `entity-mib` branch from the net-snmp fork used by this project:

```sh
git clone --branch entity-mib https://github.com/Torstein-Eide/net-snmp.git
```

Build it once so this project can link against its headers, libraries, and
ENTITY-MIB object files:

```sh
cd ~/gitwork/net-snmp
./bootstrap.sh
./configure --with-mib-modules="hardware/entity" --with-default-snmp-version="2" --with-sys-contact="root" --with-sys-location="unknown" --with-logfile="/var/log/snmpd.log" --with-persistent-directory="/var/net-snmp"
make
```

If `./bootstrap.sh` does not exist in your net-snmp checkout, run this instead:

```sh
autoreconf -fi
./configure --with-mib-modules="hardware/entity" --with-default-snmp-version="2" --with-sys-contact="root" --with-sys-location="unknown" --with-logfile="/var/log/snmpd.log" --with-persistent-directory="/var/net-snmp"
make
```

You do not need to run `sudo make install` for net-snmp unless you want to
install that source build system-wide.

## 4. Download This Project

From the same `~/gitwork` folder, clone this repository next to `net-snmp`:

```sh
cd ~/gitwork
git clone https://github.com/Torstein-Eide/net-snmp-entity-subagent.git
```

If you already have this repository, move or clone it so the final layout is:

```text
~/gitwork/net-snmp
~/gitwork/net-snmp-entity-subagent
```

## 5. Build net-snmp-entity-subagent

Build the default static binary:

```sh
cd ~/gitwork/net-snmp-entity-subagent
make
```

The output file is:

```text
./entity_subagent
```

The static build is usually the best choice for deployment because it bundles the
net-snmp libraries into the binary. It still depends on normal system libraries
such as OpenSSL, libpci, libnl, lm-sensors, and Perl runtime libraries.

To build a shared-library binary instead:

```sh
make shared
```

Use the shared build only when the target machine also has compatible net-snmp
libraries available.

To name the output file yourself:

```sh
make OUTPUT=entity_subagent-arm
```

To cross-compile, provide a cross compiler:

```sh
make CC=arm-linux-gnueabihf-gcc CFLAGS='-g -O2' OUTPUT=entity_subagent-arm
```

## 6. Configure the Master snmpd Agent

AgentX lets this subagent connect to the main `snmpd` process over a local
socket. The main `snmpd` process is called the master agent.

Edit the master agent config file:

```sh
sudo nano /etc/snmp/snmpd.conf
```

Add these lines:

```text
master agentx
agentxsocket /var/agentx/master
rocommunity public 127.0.0.1
```

The `rocommunity public 127.0.0.1` line allows read-only SNMP queries from the
local machine for testing. For production, replace it with your normal SNMP
access policy.

Restart `snmpd`:

```sh
sudo systemctl restart snmpd
```

Check that `snmpd` is running:

```sh
systemctl status snmpd
```

## 7. Run the Subagent Manually

Start the subagent from the build folder:

```sh
cd ~/gitwork/net-snmp-entity-subagent
sudo ./entity_subagent
```

It connects to `/var/agentx/master` by default.

To use a different AgentX socket path:

```sh
sudo ./entity_subagent -x /path/to/agentx.sock
```

Keep this terminal open while testing. The subagent reconnects automatically if
the master `snmpd` process restarts.

## 8. Verify ENTITY-MIB Works

Open a second terminal and run:

```sh
snmpwalk -v2c -c public localhost 1.3.6.1.2.1.47
```

If your system has the ENTITY-MIB text files installed, these symbolic names may
also work:

```sh
snmpwalk -v2c -c public localhost ENTITY-MIB::entPhysicalTable
snmpget  -v2c -c public localhost ENTITY-MIB::entLastChangeTime.0
```

If symbolic names do not work, use the numeric OID instead:

```sh
snmpwalk -v2c -c public localhost 1.3.6.1.2.1.47
```

## 9. Install as a systemd Service

After manual testing works, install the binary as a service:

```sh
sudo mkdir -p /usr/local/lib/snmpd
sudo cp ~/gitwork/net-snmp-entity-subagent/entity_subagent /usr/local/lib/snmpd/entity_subagent
sudo cp ~/gitwork/net-snmp-entity-subagent/entity_subagent.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now entity_subagent.service
```

Check the service:

```sh
systemctl status entity_subagent.service
```

View logs:

```sh
journalctl -u entity_subagent.service -f
```

## Examples

The `example/` directory contains sample ENTITY-MIB tree output from a server:

| File | Description |
|------|-------------|
| [`example/server1-detailed.tree`](example/server1-detailed.tree) | Full entity tree with all attributes (description, serial, manufacturer, URIs, alias-mappings) for each component |
| [`example/server1-compact.tree`](example/server1-compact.tree) | Compact tree showing only the entity hierarchy and names |


## How It Works

AgentX, defined by RFC 2741, lets a separate process extend an SNMP agent by
registering MIB subtrees with a master agent over a local socket. The master
proxies incoming requests for those OIDs to the subagent transparently.

The master `snmpd` agent does not need its own ENTITY-MIB implementation. It only
needs AgentX enabled with `master agentx`.

## Files

| File | Purpose |
|------|---------|
| `entity_subagent.c` | Subagent main file; sets AgentX mode and calls `init_entity()` |
| `Makefile` | Builds the subagent against the sibling `../net-snmp` tree |
| `entity_subagent.service` | systemd service file for running the subagent at boot |
| `install-entity-subagent-remote.sh` | Helper script for remote installation, if used by your deployment flow |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `../net-snmp` not found | The folders are not next to each other | Put `net-snmp-entity-subagent` and `net-snmp` in the same parent folder |
| `net-snmp/net-snmp-config.h: No such file or directory` | net-snmp was not configured | Run `./configure ...` inside `../net-snmp` |
| Missing `libssl`, `libpci`, `libnl`, `libsensors`, or `libperl` during build | Development packages are missing | Install the `-dev` or `-devel` package for the missing library |
| `error while loading shared libraries: libnetsnmpagent.so...` | Shared build used but net-snmp libraries are not installed on the target | Use `make` for the static build, or install compatible net-snmp libraries |
| `Failed to connect to the agentx master` | `snmpd` is not running, AgentX is not enabled, or the socket path is different | Start `snmpd`, add `master agentx`, and check `agentxsocket` |
| `read_config_store open failure on /var/net-snmp/...` | The state directory is not writable | Run as root, or create and grant access with `sudo mkdir -p /var/net-snmp` |
| `snmpwalk` returns nothing for `1.3.6.1.2.1.47` | The subagent is not running or has not finished registration | Start the subagent and wait a second before walking |
| Symbolic names like `ENTITY-MIB::entPhysicalTable` do not resolve | Local MIB text files are not installed or loaded | Use numeric OID `1.3.6.1.2.1.47`, or install/load ENTITY-MIB files |
| Duplicate OID errors in the master log | Another agent also registered ENTITY-MIB | Disable the duplicate ENTITY-MIB provider |

## Clean Build Files

To remove this project's generated files:

```sh
make clean
```

To rebuild from scratch:

```sh
make clean
make
```
