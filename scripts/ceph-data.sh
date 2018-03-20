#!/bin/sh
#
# ceph-data.sh <cluster_name> <mons|osds|pools|health> [client_hostname_in_zabbix]
# 20171201-20171207 v1.1 stas630
#
#
ZBX_CONFIG_AGENT="/etc/zabbix/zabbix_agentd.conf"
# Uncomment if need log
#LOG="/var/log/zabbix-agent/ceph.log"
#
#
CLUSTER_NAME=$1
OPERATION=$2
HOSTNAME=$3

export PATH=/bin:/usr/bin
TMPS=`mktemp -t zbx-ceph.XXXXXXXXXXX`

case ${OPERATION} in
  monitor)
    HOSTNAME_MON=$(hostname -s)
    if [ -e /var/run/ceph/${CLUSTER_NAME}-mon.${HOSTNAME_MON}.asok ];
    then
     ceph daemon mon.${HOSTNAME_MON} mon_status 2>/dev/null | jq -e '.state == "leader"' &> /dev/null
     RET="$?"
     if [ "$RET" = "0" ];then
        echo "INFO: This is the leader, gathering data and sending it to the zabbix server"
     else
        echo "INFO: This is not the leader, skipping execution"
        exit $RET
     fi
   else
     echo "ERROR: This is not a mon server"
     exit 1
   fi 
   (
   set -x
   $0 ${CLUSTER_NAME} mons $HOSTNAME
   $0 ${CLUSTER_NAME} osds $HOSTNAME
   $0 ${CLUSTER_NAME} pools $HOSTNAME
   $0 ${CLUSTER_NAME} health $HOSTNAME
   ) 2>&1 | tee /tmp/ceph-data.out
   echo "INFO: logged output to /tmp/ceph-data.out"
  ;;
  osds)
    ceph --cluster ${CLUSTER_NAME} osd df tree -f json |\
      jq -r '(.nodes[]|select(.type=="osd")|"\(.name) \(.kb_avail / 1048576)"),
        "ceph.spaceavail \(.summary.total_kb_avail / 1048576)",
        "ceph.spacetotal \(.summary.total_kb / 1048576)"'|\
      awk '
        BEGIN{ print "{\"data\":[" }
        {
          if($1~/^osd/){
            if(NR!=1){ printf "," }
            print "{ \"{#OSD}\":\""$1"\" }"
            print "'$HOSTNAME' ceph.osdspaceavail["$1"] "$2 >"'${TMPS}'"
          }else{
            print "'$HOSTNAME' "$1" "$2 >"'${TMPS}'"
          }
        }
        END{ print "]}" }'
    ceph --cluster ${CLUSTER_NAME} osd dump -f json |\
      jq -r '(.osds[]| "'${HOSTNAME}' ceph.osdstatus[osd.\(.osd)] \(.up)"),
        "'${HOSTNAME}' ceph.osdcount \(.max_osd)"' >>${TMPS}
  ;;

  pools)
    ceph --cluster ${CLUSTER_NAME} df -f json |\
      jq -r '.pools[]|"\(.name) \(.stats.max_avail / 1073741824)"'|\
      awk '
        BEGIN{ print "{\"data\":[" }
        {
          if(NR!=1){ printf "," }
          print "{ \"{#POOL}\":\""$1"\" }"
          print "'$HOSTNAME' ceph.poolspaceavail["$1"] "$2 >"'${TMPS}'"
        }
        END{ print "]}" }'
  ;;

  mons)
    ceph --cluster ${CLUSTER_NAME} mon dump 2>/dev/null -f json |\
      jq -r  'reduce .mons[] as $mon ({rquorum:.quorum,rmons:{}}; . + {rmons:(.rmons+ { ($mon.name):(.rquorum| if index($mon.rank)==null then 0 else 1 end) })} ) |.rmons|to_entries[]|"\(.key) \(.value)"'|\
      awk '
        BEGIN{ print "{\"data\":[" }
        {
          if(NR!=1){ printf "," }
          print "{ \"{#MON}\":\""$1"\" }"
          print "'$HOSTNAME' ceph.monstatus["$1"] "$2 >"'${TMPS}'"
        }
        END{ print "]}" }'
  ;;

  health)
    ceph --cluster ${CLUSTER_NAME} status -f json |\
      jq -r '
        "\(if .health.status =="HEALTH_OK" then 1 elif .health.status =="HEALTH_WARN" then 2 else 0 end)",
        "ceph.moncount \(.monmap.mons|length)",
        "ceph.pgtotal \(.pgmap.num_pgs)",
        "ceph.activating \(.pgmap.pgs_by_state|map(select(.state_name|contains("activating")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.active \(.pgmap.pgs_by_state|map(select(.state_name|contains("active")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfilling \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfilling")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfill_toofull \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfill_toofull")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfill_unfound \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfill_unfound")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfill_wait \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfill_wait")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.clean \(.pgmap.pgs_by_state|map(select(.state_name|contains("clean")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.creating \(.pgmap.pgs_by_state|map(select(.state_name|contains("creating")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.deep \(.pgmap.pgs_by_state|map(select(.state_name|contains("deep")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.degraded \(.pgmap.pgs_by_state|map(select(.state_name|contains("degraded")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.down \(.pgmap.pgs_by_state|map(select(.state_name|contains("down")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.forced_backfill \(.pgmap.pgs_by_state|map(select(.state_name|contains("forced_backfill")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.forced_recovery \(.pgmap.pgs_by_state|map(select(.state_name|contains("forced_recovery")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.incomplete \(.pgmap.pgs_by_state|map(select(.state_name|contains("incomplete")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.inconsistent \(.pgmap.pgs_by_state|map(select(.state_name|contains("inconsistent")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.peered \(.pgmap.pgs_by_state|map(select(.state_name|contains("peered")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.peering \(.pgmap.pgs_by_state|map(select(.state_name|contains("peering")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovering \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovering")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovery_toofull \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovery_toofull")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovery_unfound \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovery_unfound")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovery_wait \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovery_wait")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.remapped \(.pgmap.pgs_by_state|map(select(.state_name|contains("remapped")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.repair \(.pgmap.pgs_by_state|map(select(.state_name|contains("repair")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.scrubbing \(.pgmap.pgs_by_state|map(select(.state_name|contains("scrubbing")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.snaptrim \(.pgmap.pgs_by_state|map(select(.state_name|contains("snaptrim")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.snaptrim_error \(.pgmap.pgs_by_state|map(select(.state_name|contains("snaptrim_error")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.snaptrim_wait \(.pgmap.pgs_by_state|map(select(.state_name|contains("snaptrim_wait")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.stale \(.pgmap.pgs_by_state|map(select(.state_name|contains("stale")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.undersized \(.pgmap.pgs_by_state|map(select(.state_name|contains("undersized")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.num_up_osds \(.osdmap.osdmap.num_up_osds)",
        "ceph.num_in_osds \(.osdmap.osdmap.num_in_osds)",
        "ceph.rdbps \(.pgmap.read_bytes_sec)",
        "ceph.wrbps \(.pgmap.write_bytes_sec)",
        "ceph.opsread \(.pgmap.read_op_per_sec)",
        "ceph.opswrite \(.pgmap.write_op_per_sec)"'|\
        awk '{
          if(NR==1){
            print
          }else{
            print "'$HOSTNAME' "$0> "'${TMPS}'"
          }
        }'
  ;;
esac

if [ -z ${HOSTNAME} ]; then
  cat ${TMPS}
elif [ -s ${TMPS} ]; then
  if [ -z ${LOG} ]; then
    zabbix_sender -c ${ZBX_CONFIG_AGENT} -i ${TMPS}
  else
    zabbix_sender -c ${ZBX_CONFIG_AGENT} -i ${TMPS}  -vv >> ${LOG} 2>&1
  fi
fi

rm -f ${TMPS}
