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
* Install cronjob <BR>(replace ceph-prod.foo-bar.com with the cluster host name)
  ```
  cat <<'EOF'
  */3 * * * * root /usr/local/bin/ceph_monitoring_data.sh ceph health ceph-prod.foo-bar.com >/dev/null 2>&1
  */3 * * * * root /usr/local/bin/ceph_monitoring_data.sh ceph osds ceph-prod.foo-bar.com >/dev/null 2>&1
  */10 * * * * root /usr/local/bin/ceph_monitoring_data.sh ceph mons ceph-prod.foo-bar.com >/dev/null 2>&1
  */15 * * * * root /usr/local/bin/ceph_monitoring_data.sh ceph pools ceph-prod.foo-bar.com >/dev/null 2>&1
  EOF
  ```
* Configure Zabbix Agent
  * Check arguments: ServerActive, Hostname, ListenIP in zabbix_agentd.conf
  * Check permission for read user zabbix /etc/ceph/<{$CLUSTER_NAME}>.client.admin.keyring
  * Finally in zabbix setup the discovery rule and related items you need.# ceph-zabbix

TODOs
======

- Eliminate tmp file
- Convert this script to python
- Add functionality to offical ceph monitoring agent
