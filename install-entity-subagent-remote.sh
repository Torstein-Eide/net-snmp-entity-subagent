#!/bin/sh

# Install the ENTITY-MIB AgentX subagent on a remote system over SSH.
# Usage: ./install-entity-subagent-remote.sh user@host

set -eu

usage()
{
    printf 'usage: %s user@host\n' "$0" >&2
    exit 2
}

[ "$#" -eq 1 ] || usage

REMOTE=$1
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR" && pwd)

BINARY=$ROOT_DIR/entity_subagent
SERVICE=$ROOT_DIR/entity_subagent.service
REMOTE_BIN=/usr/local/lib/snmpd/entity_subagent
REMOTE_SERVICE=/etc/systemd/system/entity_subagent.service
SERVICE_NAME=entity_subagent.service

[ -f "$BINARY" ] || { printf 'missing binary: %s\n' "$BINARY" >&2; exit 1; }
[ -f "$SERVICE" ] || { printf 'missing service: %s\n' "$SERVICE" >&2; exit 1; }

if ssh "$REMOTE" "test -f '$REMOTE_SERVICE' || systemctl list-unit-files '$SERVICE_NAME' >/dev/null 2>&1"; then
    printf 'existing service found on %s; stopping before upgrade\n' "$REMOTE"
    ssh -t "$REMOTE" "sudo systemctl stop '$SERVICE_NAME' || true"
    INSTALL_MODE=upgrade
else
    printf 'service not installed on %s; doing first install\n' "$REMOTE"
    INSTALL_MODE=install
fi

REMOTE_TMP=$(ssh "$REMOTE" "mktemp -d /tmp/entity-subagent-install.XXXXXX")
cleanup()
{
    ssh "$REMOTE" "rm -rf '$REMOTE_TMP'" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

printf 'copying files to %s\n' "$REMOTE"
scp "$BINARY" "$SERVICE" "$REMOTE:$REMOTE_TMP/"

printf '%s service on %s\n' "$INSTALL_MODE" "$REMOTE"
ssh -t "$REMOTE" "sudo install -d -m 0755 /usr/local/lib/snmpd && \
    sudo install -m 0755 '$REMOTE_TMP/entity_subagent' '$REMOTE_BIN' && \
    sudo install -m 0644 '$REMOTE_TMP/entity_subagent.service' '$REMOTE_SERVICE' && \
    sudo systemctl daemon-reload && \
    sudo systemctl enable '$SERVICE_NAME' && \
    sudo systemctl restart '$SERVICE_NAME' && \
    sudo systemctl --no-pager --full status '$SERVICE_NAME'"

cleanup
trap - EXIT HUP INT TERM

printf 'installed entity_subagent on %s\n' "$REMOTE"
