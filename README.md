# CentOSCluster
Hadoop,Zookeeper,Flink等集群配置

## 虚拟机配置!!
OS:Centos7三台  
master一台,slave两台.  
>1.后面会配置HA,这只是个hostname.  
每台机器配置下hosts文件.  
2.创建hadoop用户并配置sudo  
为了各软件管理方便,一律放在/home/hadoop目录下,以hadoop用户进行操作.  
3.切换hadoop用户在/home/hadoop下设置ssh免密,关闭防火墙,并关闭Selinux!  

## hadoop2.7.7基本配置
按照[hadoop基本配置](https://github.com/huija/CentOSCluster/tree/master/hadoop2.7.7_base_settings),修改相关hostname及路径,放到你的配置文件夹中.  
>每一个分布式软件的安装,都需要配置环境变量,一般将bin放到PATH中就可以了(某些需要配sbin和lib等等).

### 启动你的hadoop集群:  
``` bash
hdfs namenode -format
start-dfs.sh
start-yarn.sh
```
注:访问jobhistory的19888端口提示404,是因为jobhistory的进程需要单独启动:
``` bash
mr-jobhistory-daemon.sh start historyserver
```

### 查看状态
jps查看启动进程
>master上:NameNode,SecondaryNameNode,ResourceManager,JobHistoryServer  
slaves上:DataNode,NodeManager

或者直接在浏览器访问hdfs和yarn管理台:
>master:8080和master:50070

### 运行mapreduce任务
启动hadoop本身的wordcount示例:
``` bash
cat > demo.txt << EOF
helloword
happy happy
coding coding coding
study study study study
EOF
hadoop fs -mkdir /wordcount
hadoop fs -put demo.txt /wordcount
hadoop fs -ls /wordcount
hadoop jar /home/hadoop/hadoop-2.7.7/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.7.jar wordcount /wordcount /wcresult0
```
可以在master:8088/cluster/apps进行任务追踪!  
查看结果:
``` bash
[hadoop@master ~]$ hadoop fs -ls /wcresult0
Found 2 items
-rw-r--r--   2 hadoop supergroup          0 2019-01-09 21:17 /wcresult0/_SUCCESS
-rw-r--r--   2 hadoop supergroup         37 2019-01-09 21:17 /wcresult0/part-r-00000
[hadoop@master ~]$ hadoop fs -cat /wcresult0/part-r-00000
coding	3
happy	2
helloword	1
study	4
```

### 关闭集群:
``` bash
mr-jobhistory-daemon.sh stop historyserver
stop-yarn.sh
stop-dfs.sh
```
注:如果格式化,需要删除子节点的dfs目录,否则再启动,datanode会down掉!

## zookeeper3.4.13基本配置
zookeeper的集群个数选单数.  
在各个机器上安装好zookeeper,[配置好zoo.cfg](https://github.com/huija/CentOSCluster/tree/master/zookeeper3.4.13_base_settings),然后对应设置好每个机器的myid,zookeeper集群就搭建好了.
``` bash
mkdir -p /home/hadoop/zookeeper-3.4.13/mydir/data
cd /home/hadoop/zookeeper-3.4.13/mydir/data
cat > myid << EOF
1
EOF
```
### zookeeper集群启动
zookeeper的启动需要到各个机器上单独进行启动,具体启动命令如下:
``` bash
zkServer.sh start
```
启动后使用jps查看进程,如果看到QuorumPeerMain进程,说明这个机器上的zookeeper就启动了.  
同理,依次启动所有机器上的zookeeper.  
接着每个机器可以使用命令查看自己的状态:
``` bash
zkServer.sh status
```
主要分为leader和follower.
### zookeeper集群关闭
``` bash
zkServer.sh stop
```
注:有时候使用zookeeper启动不起来,发现2181端口被进程占用,但是进程没有pid,原因是不同的用户启动了zookeeper(虽然一个人不会遇见这种问题).