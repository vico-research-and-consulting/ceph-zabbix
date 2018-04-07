# ceph-zabbix

A zabbix probe to get performance counters of ceph (Luminous 12.2+)

[Documentation of the Zabbix Template](http://htmlpreview.github.io/?https://github.com/vico-research-and-consulting/ceph-zabbix/blob/master/zabbix_templates/zbx_ceph_template.html)


Installation
============

* Install jq:
  ```
  sudo apt install jq zabbix-sender
  ```
* Install script
  ```
  cp scripts/ceph-data.sh /usr/local/bin/zabbix_ceph-data.sh
  ```
* Install cronjob <BR>(configure variables)
  ```
  cat >/etc/cron.d/ceph_monitoring_data <<'EOF'
  CLUSTER_NAME="ceph"
  ZABBIX_CLUSTER_NAME="ceph-prod.foo-bar.com"


  */3 * * * * root /usr/local/bin/ceph_monitoring_data.sh $CLUSTER_NAME health $ZABBIX_CLUSTER_NAME >/dev/null 2>&1
  */3 * * * * root /usr/local/bin/ceph_monitoring_data.sh $CLUSTER_NAME osds $ZABBIX_CLUSTER_NAME >/dev/null 2>&1
  */10 * * * * root /usr/local/bin/ceph_monitoring_data.sh $CLUSTER_NAME mons $ZABBIX_CLUSTER_NAME >/dev/null 2>&1
  */15 * * * * root /usr/local/bin/ceph_monitoring_data.sh $CLUSTER_NAME pools $ZABBIX_CLUSTER_NAME >/dev/null 2>&1
  EOF
  ```
* Configure Zabbix Agent
  * Check arguments: ServerActive, Hostname, ListenIP in zabbix_agentd.conf
  * Check permission for read user zabbix /etc/ceph/<{$CLUSTER_NAME}>.client.admin.keyring
  * Finally in zabbix setup the discovery rule and related items you need.# ceph-zabbix
* Invoke initial discovery
  ```
  /usr/local/bin/ceph_monitoring_data.sh ceph health ceph-prod.foo-bar.com
  ```

TODOs
======

- Eliminate tmp file
- Convert this script to python
- Add functionality to offical ceph monitoring agent
