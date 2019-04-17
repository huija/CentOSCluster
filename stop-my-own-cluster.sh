#!/bin/bash
stop-hbase.sh
read -p "run [yarn-daemon.sh stop resourcemanager] on your standby please!!" var
mr-jobhistory-daemon.sh stop historyserver
stop-yarn.sh
stop-dfs.sh
