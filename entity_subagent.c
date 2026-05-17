/*
 * AgentX subagent that registers the ENTITY-MIB (1.3.6.1.2.1.47).
 *
 * Usage:
 *   1. Start master snmpd with "master agentx" in snmpd.conf
 *   2. Run this binary; it connects via /var/agentx/master by default
 *   3. snmpwalk -v2c -c public localhost 1.3.6.1.2.1.47
 *
 * Debug:
 *   LOG_NOTICE - OID subtrees registered (local) and forwarded (master)
 *   LOG_DEBUG  - individual OID hits; enable with -d flag
 */

#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <net-snmp/agent/net-snmp-agent-includes.h>
#include <net-snmp/agent/agent_callbacks.h>
#include <net-snmp/agent/agent_registry.h>

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

/* ------------------------------------------------------------------ debug */

static const char *mode_str(int mode)
{
    switch (mode) {
    case MODE_GET:          return "GET";
    case MODE_GETNEXT:      return "GETNEXT";
    case MODE_GETBULK:      return "GETBULK";
    case MODE_SET_RESERVE1: return "SET-RESERVE1";
    case MODE_SET_RESERVE2: return "SET-RESERVE2";
    case MODE_SET_ACTION:   return "SET-ACTION";
    case MODE_SET_COMMIT:   return "SET-COMMIT";
    case MODE_SET_FREE:     return "SET-FREE";
    case MODE_SET_UNDO:     return "SET-UNDO";
    default:                return "?";
    }
}

/*
 * Pass-through handler injected into each handler chain when -d is active.
 * Logs every incoming OID request at LOG_DEBUG level without affecting the
 * response.
 */
static int debug_request_handler(netsnmp_mib_handler          *handler,
                                 netsnmp_handler_registration *reginfo,
                                 netsnmp_agent_request_info   *reqinfo,
                                 netsnmp_request_info         *requests)
{
    netsnmp_request_info *req;
    for (req = requests; req; req = req->next) {
        char buf[256];
        snprint_objid(buf, sizeof(buf),
                      req->requestvb->name, req->requestvb->name_length);
        snmp_log(LOG_DEBUG, "entity_subagent: OID hit %s mode=%s handler=%s\n",
                 buf, mode_str(reqinfo->mode),
                 reginfo->handlerName ? reginfo->handlerName : "?");
    }
    return netsnmp_call_next_handler(handler, reginfo, reqinfo, requests);
}

/*
 * Callback fired for each OID subtree registered with the local agent,
 * and again when that registration is forwarded to the AgentX master.
 *
 * Always logs at LOG_NOTICE.  When *inject != 0 (i.e. -d was passed),
 * also injects the debug pass-through handler on the first firing so
 * that OID hits are logged.  The already-injected check prevents a
 * second injection on the master-forwarding firing.
 */
static int on_register_oid(int major, int minor,
                           void *serverarg, void *clientarg)
{
    struct register_parameters *rp = (struct register_parameters *)serverarg;
    int inject = clientarg && *(int *)clientarg;
    char buf[256];
    int already = 0;

    (void)major; (void)minor;

    if (!rp || !rp->reginfo)
        return SNMP_ERR_NOERROR;

    snprint_objid(buf, sizeof(buf), rp->name, rp->namelen);

    if (inject) {
        netsnmp_mib_handler *h;
        for (h = rp->reginfo->handler; h; h = h->next)
            if (strcmp(h->handler_name, "entity_debug") == 0) {
                already = 1;
                break;
            }
    }

    snmp_log(LOG_NOTICE,
             "entity_subagent: registered (%s) %s [%s]\n",
             already ? "master" : "local",
             buf,
             rp->reginfo->handlerName ? rp->reginfo->handlerName : "?");

    if (inject && !already) {
        netsnmp_mib_handler *dbg =
            netsnmp_create_handler("entity_debug", debug_request_handler);
        if (dbg)
            netsnmp_inject_handler(rp->reginfo, dbg);
    }

    return SNMP_ERR_NOERROR;
}

int main(int argc, char **argv)
{
    int debug = 0;
    int i;
    for (i = 1; i < argc; i++)
        if (strcmp(argv[i], "-d") == 0)
            debug = 1;

    /* Tell the library we are a subagent, not the master */
    netsnmp_ds_set_boolean(NETSNMP_DS_APPLICATION_ID,
                           NETSNMP_DS_AGENT_ROLE, 1);

    /* Optional: override the AgentX socket path */
    /* netsnmp_ds_set_string(NETSNMP_DS_APPLICATION_ID,
                             NETSNMP_DS_AGENT_X_SOCKET,
                             "/var/agentx/master"); */

    SOCK_STARTUP;

    /* Suppress MIB file loading — the subagent serves numeric OIDs only */
    setenv("MIBS", "", 1);

    init_agent("entity_subagent");

    /* Always log registrations; inject OID-hit handler only with -d */
    netsnmp_register_callback(SNMP_CALLBACK_APPLICATION,
                              SNMPD_CALLBACK_REGISTER_OID,
                              on_register_oid, &debug,
                              NETSNMP_CALLBACK_DEFAULT_PRIORITY);

    init_entity();
    init_entPhysicalTable();
    init_entLastChangeTime();
    init_entAliasMappingTable();
    init_entLogicalTable();
#if defined(linux)
    init_entity_linux();
#endif

    if (debug) {
        snmp_enable_stderrlog();
        snmp_set_do_debugging(1);
    }

    /*
     * Ping the AgentX master every 15 s.  When the master is gone the ping
     * times out, triggering agentx_reopen_session() inside the library which
     * reconnects and re-registers all OIDs once snmpd comes back.
     * Without this the subagent sits silently disconnected forever.
     */
    netsnmp_ds_set_int(NETSNMP_DS_APPLICATION_ID,
                       NETSNMP_DS_AGENT_AGENTX_PING_INTERVAL, 15);

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
