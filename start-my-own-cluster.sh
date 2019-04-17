#!/bin/bash
start-dfs.sh
start-yarn.sh
mr-jobhistory-daemon.sh start historyserver
read -p "run [yarn-daemon.sh start resourcemanager] on your standby please!!" var
start-hbase.sh