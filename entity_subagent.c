/*
 * AgentX subagent that registers the ENTITY-MIB (1.3.6.1.2.1.47).
 *
 * Usage:
 *   1. Start master snmpd with "master agentx" in snmpd.conf
 *   2. Run this binary; it connects via /var/agentx/master by default
 *   3. snmpwalk -v2c -c public localhost 1.3.6.1.2.1.47
 */

#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <net-snmp/agent/net-snmp-agent-includes.h>

#include "agent/mibgroup/hardware/entity/entity.h"
#include "agent/mibgroup/hardware/entity/entPhysicalTable.h"
#include "agent/mibgroup/hardware/entity/entLastChangeTime.h"
#include "agent/mibgroup/hardware/entity/entAliasMappingTable.h"
#include "agent/mibgroup/hardware/entity/entLogicalTable.h"
#if defined(linux)
#include "agent/mibgroup/hardware/entity/data_access/entity_linux.h"
#endif

static volatile int keep_running = 1;

static void stop_handler(int sig)
{
    (void)sig;
    keep_running = 0;
}

int main(int argc, char **argv)
{
    (void)argc; (void)argv;

    /* Tell the library we are a subagent, not the master */
    netsnmp_ds_set_boolean(NETSNMP_DS_APPLICATION_ID,
                           NETSNMP_DS_AGENT_ROLE, 1);

    /* Optional: override the AgentX socket path */
    /* netsnmp_ds_set_string(NETSNMP_DS_APPLICATION_ID,
                             NETSNMP_DS_AGENT_X_SOCKET,
                             "/var/agentx/master"); */

    SOCK_STARTUP;

    init_agent("entity_subagent");
    init_entity();
    init_entPhysicalTable();
    init_entLastChangeTime();
    init_entAliasMappingTable();
    init_entLogicalTable();
#if defined(linux)
    init_entity_linux();
#endif

    init_snmp("entity_subagent");

    signal(SIGTERM, stop_handler);
    signal(SIGINT,  stop_handler);

    snmp_log(LOG_INFO, "entity_subagent started, waiting for requests\n");

    while (keep_running)
        agent_check_and_process(1);

    snmp_shutdown("entity_subagent");
    SOCK_CLEANUP;
    return 0;
}
