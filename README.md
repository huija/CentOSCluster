# CentOSCluster
Hadoop,Zookeeper,Flink等集群配置
# 目录
### [1.虚拟机配置!!](#虚拟机配置!!)
### [2.hadoop2.7.7基本配置](#hadoop2.7.7基本配置)
### [3.zookeeper3.4.13基本配置](#zookeeper3.4.13基本配置)
### [4.NameNode的HA配置](#NameNode的HA配置)
### [5.ResourceManager的HA配置](#ResourceManager的HA配置)
### [6.Flink Standalone](#Flink集群部署)

### [6.1阶段性小结](#阶段性总结)

### [7.搭建postgresql的hostandby环境](#hotstandby)

### [8.kafka_2.12-2.1.1集群搭建](#kafka集群)

### [9.redis-5.0.3集群搭建](#Redis集群)

### [10.我的/etc/profile环境变量添加如下](#环境变量)

<span id="虚拟机配置!!"></span>

## 虚拟机配置!!
OS:Centos7三台  
master一台,slave两台.  

>1.后面会配置HA,这只是个hostname.  
每台机器配置下hosts文件.  
2.创建hadoop用户并配置sudo  
为了各软件管理方便,一律放在/home/hadoop目录下,以hadoop用户进行操作.  
3.切换hadoop用户在/home/hadoop下设置ssh免密,关闭防火墙,并关闭Selinux!  

<span id="hadoop2.7.7基本配置"></span>
## hadoop2.7.7基本配置
按照[hadoop基本配置](https://github.com/huija/CentOSCluster/tree/master/hadoop2.7.7_base_settings),修改相关hostname及路径,放到你的配置文件夹中.  
>每一个分布式软件的安装,都需要[配置环境变量](#环境变量),一般将bin放到PATH中就可以了(某些需要配sbin和lib等等).

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

<span id="zookeeper3.4.13基本配置"></span>
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
注:有时候使用zookeeper启动不起来,发现2181端口被进程占用,但是进程没有pid,原因是不同的用户启动了zookeeper(使用root用户可以看到所有).

<span id="NameNode的HA配置"></span>
## NameNode的HA配置
初始化hadoop集群,关闭所有集群.    
在前面hadoop集群配置的基础上,对每台机器的core-site.xml以及hdfs-site.xml[添加相关配置](https://github.com/huija/CentOSCluster/tree/master/namenode_HA).  
### 启动配置好NameNode HA的hdfs
第一次启动略微繁琐.   
1.启动zookeeper集群
``` bash
zkServer.sh start
```
2.在每台NameNode上创建命名空间
``` bash
hdfs zkfc -formatZK
```
3.启动journalnode(节点数取单数,每台都运行下面命令)
``` bash
hadoop-daemon.sh start journalnode
```
4.主节点上对NameNode和journalnode集群格式化
``` bash
hdfs namenode -format NNHA
```
5.主节点上启动NameNode (Active)
``` bash
hadoop-daemon.sh start namenode
```
6.启动从节点上的Namenode (Standby)
``` bash
hdfs namenode -bootstrapStandby
hadoop-daemon.sh start namenode
```
7.主从节点上都启动ZKFC
``` bash
hadoop-daemon.sh start zkfc
```
8.在所有节点上启动DataNode
``` bash
hadoop-daemon.sh start datanode
```
到这里NameNode的HA就配置完成了.  
后续的hdfs启动停止与之前[基本配置](#hadoop2.7.7基本配置)时的命令一致即可
### 查看各节点进程
1.master节点,也就是Active NameNode:
``` bash
[hadoop@master ~]$ jps
20289 QuorumPeerMain
31382 Jps
31289 DFSZKFailoverController
31084 JournalNode
30845 NameNode
```
对比基本配置,多了DFSZKFailoverController和JournalNode进程,一个是为了自动切换主备,一个是NameNode元数据备份共享.  
2.slave1节点,也就是Satndby NameNode:
``` bash
[hadoop@slave1 ~]$ jps
17328 QuorumPeerMain
22240 JournalNode
22368 DFSZKFailoverController
22147 NameNode
22534 Jps
```
对比基本配置DataNode变成了NameNode,同时多了DFSZKFailoverController和JournalNode进程  
3.slave2节点,也就是DataNode节点:
``` bash
[hadoop@slave2 ~]$ jps
21650 DataNode
17209 QuorumPeerMain
21742 JournalNode
21918 Jps
```
多了一个JournalNode进程.
### Web界面进行HA的可用性检验.
通过kill掉Active的NameNode进程,查看StandBy的NameNode是否会转变为Active!  
NameNode网页界面:master:50070和slave1:50070.

<span id="ResourceManager的HA配置"></span>

## ResourceManager HA配置
在前面配置的基础上,配置好[yarn-site.xml](https://github.com/huija/CentOSCluster/tree/master/resourcemanager_HA).
### 启动配置好的yarn
这一次启动并没有NameNode的HA第一次启动那么繁琐,虽然都是通过zookeeper来实现HA,但是细节上两个还是有很多区别的.  
直接集群启动:
``` bash
start-yarn.sh
```
这时候查看进程,你会发现备用的ResourceManager并没有启动,三台机器的启动进程如下:
``` bash
[hadoop@master ~]$ jps
35683 Jps
34168 ResourceManager
35016 JobHistoryServer
31289 DFSZKFailoverController
31084 JournalNode
30845 NameNode
32638 QuorumPeerMain

[hadoop@slave1 ~]$ jps
22240 JournalNode
22368 DFSZKFailoverController
22147 NameNode
24583 Jps
23259 QuorumPeerMain

[hadoop@slave2 ~]$ jps
21650 DataNode
24262 Jps
22553 QuorumPeerMain
21742 JournalNode
23103 NodeManager
```
其实,我们的配置没有问题,主要的区别在于,备用的RM需要我们在对应机器上手动进行启动:
``` bash
yarn-daemon.sh start resourcemanager
```
这时候备用的RM就启动了,同样的,关闭集群的时候,建议先关闭备用的这个RM.
### RM HA高可用验证
与NN HA中两个NameNode都可以分别通过web访问不同,同一时间,只有一个ResourceManager能通过web访问
>例如,此时master:8088是yarn的管理界面,那么访问slave1:8088,就会自动跳转到master8088.

检验方法就是kill掉master上的ResourceManager,接着看slave1:8088,能不能接替被杀的RM,管理资源,接管任务.
>可以尝试在yarn上运行程序的时候,进行这一步,程序并不会受到影响.

<span id="Flink集群部署"></span>

## Flink Standalone

> flink有两种运行模式,分为standalone和on yarn,on yarn我本机资源不够,启动不起来,而且能standalone部署了,那么基本on yarn不存在什么问题.

在master上解压flink安装包, [并进行设置](https://github.com/huija/CentOSCluster/tree/master/flink-1.7.1_standalone). 然后将master上的flink拷贝到需要的slave上!

### 启动flink standalone集群

```bash
[hadoop@master ~]$ start-cluster.sh
Starting cluster.
Starting standalonesession daemon on host master.
Starting taskexecutor daemon on host slave1.
Starting taskexecutor daemon on host slave2.
```

通过上述命令启动集群.

在master和slave上的进程名分别为:

> StandaloneSessionClusterEntrypoint
>
> TaskManagerRunner

### 启动flink独特的实时流式wc

1. 首先在master启动nc

```bash
[hadoop@master ~]$ nc -lk 9999

```

9999端口会进入监听状态.

1. 然后再slave1启动task(不启动nc, 这个run会失败)

```bash
[hadoop@slave1 ~]$ flink run flink-1.7.1/examples/streaming/SocketWindowWordCount.jar --hostname master --port 9999
Starting execution of program

```

如上, 任务就算部署到flink集群上了.

1. 接着在http://master:8081找到运行中的任务, 查看其log会输出到那台slave上.

具体是在"Sink: Print to Std. Out"这个子任务内的Host属性值

> 我的是slave1:46186, 也就是说log会在slave1下的flink目录的log目录里, 找到最新的out文件

1. 对流式wc的outlog进行监听输出

```bash
[hadoop@slave1 ~]$ tail -f flink-1.7.1/log/flink-hadoop-taskexecutor-0-slave1.out

```

初始是空的, 后面流式数据的一个wc会输入进入.

到这里, flink本身的wordcount就运行好了.

1. 进行wordcount体验, 在nc的窗口输入我们的数据

```bash
[hadoop@master ~]$ nc -lk 9999
1
2 2
3 3 3
4 4 4 4

```

与之对应的tail窗口的outlog会输出如下

```bash
[hadoop@slave1 ~]$ tail -f flink-1.7.1/log/flink-hadoop-taskexecutor-0-slave1.out
1 : 1
3 : 3
2 : 2
4 : 4

```

## 阶段性总结

到这里就搭建好了初步的hadoop,zookeeper,flink集群, 进程可以通过jps查看.

> flink的HA也是通过zookeeper, 我就不试了.

如今集群全开的情况下, 关闭的步骤如下:

```bash
1.master上关闭flink集群
stop-cluster.sh
2.slave1上关闭备用的ResourceManager
yarn-daemon.sh stop resourcemanager
3.master上关闭hadoop集群
mr-jobhistory-daemon.sh stop historyserver
stop-yarn.sh
stop-dfs.sh
4.master,slave1,slave2上分别关闭zookeeper进程
zkServer.sh stop
```

到这, jps应该查不到运行的相关进程了, 后面想要开启集群的时候, 只要反过来开就行了, 具体遇到问题, 可以具体再分析.

> 将hadoop的启动命令全写到了脚本内, zk和flink的就一个命令就不放了.

<span id="hotstandby"></span>

## 搭建postgresql的hostandby环境

### [postgresql源码安装](https://huija.github.io/2019/03/01/postgresql-source/)

### [hotstandby环境搭建](https://huija.github.io/2019/03/02/postgresql-hotstandby/)

<span id="kafka集群"></span>

## kafka_2.12-2.1.1集群搭建

>  kafka集群依赖于zookeeper集群, 其创建的topic等信息都会存在zookeeper, 所有需要先启动zookeeper.
>
> 我把kafka整个删了之后, 再安装, 发现zookeeper内的相关znode还在, 太恐怖了.

首先下载压缩包, 解压在/home/hadoop目录下, [配置环境变量](#环境变量), 然后进入$KAFKA_HOME/conf目录, [进行相关配置](https://github.com/huija/CentOSCluster/tree/master/kafka_2.12-2.1.1_base_settings). 主要配置以下三行

```properties
# The id of the broker. This must be set to a unique integer for each broker.
broker.id=0
# A comma separated list of directories under which to store log files
log.dirs=/home/hadoop/kafka_2.12-2.1.1/logs
# root directory for all kafka znodes.
zookeeper.connect=master:2181,slave1:2181,slave2:2181
```

其中broker.id三台机器分别不一样, 其余两个配置一样.

### 启动kafka集群

kafka的集群类型跟zookeeper比较像, 每一个节点都需要进行启动.

```bash
[hadoop@slave2 config]$ kafka-server-start.sh -daemon server.properties
[hadoop@slave2 config]$ jps
42568 QuorumPeerMain
53914 Jps
53853 Kafka
```

三台机器上都出现Kafka的进程后, 集群就已经搭建好了, 而且是跟zookeeper一样的高可用模式.

### 运行简单示例

1. 创建Topic, 设定复制因子和分区.

   > 按照物理机隔离来说的话，zk必须是3台以上才能保证高可用，replication也得3，分区的话，既然不是逻辑分区，是物理分区就1就好了。这是只有3台机器并且不计成本的方案。

   ```bash
   [hadoop@master config]$ kafka-topics.sh --create --zookeeper master:2181 --replication-factor 3 --partitions 1 --topic test
   ....
   ```

2. 查看Topic是否创建(列出topic列表)

   ```bash
   [hadoop@master config]$ kafka-topics.sh --zookeeper master:2181 -list
   __consumer_offsets
   test
   ```

3. 在任意一个终端启动一个Producer

   ```bash
   [hadoop@master config]$ kafka-console-producer.sh --broker-list slave1:9092 --topic test
   >
   ```

4. 接着在另外一个终端启动一个Consumer

   ```bash
   [hadoop@slave1 config]$ kafka-console-consumer.sh --bootstrap-server slave1:9092 --topic test --from-beginning
   ```

5. 在Producer终端输入消息,与此同时可以看到Consumer的终端有消息打印出来

   ```bash
   [hadoop@master config]$ kafka-console-producer.sh --broker-list slave1:9092 --topic test
   >hhh
   >nizhidaoma
   >xiezailehaizai
   >nipabupa
   >woshipale
   >
   ```

   ```bash
   [hadoop@slave1 config]$ kafka-console-consumer.sh --bootstrap-server slave1:9092 --topic test --from-beginning
   hhh
   nizhidaoma
   xiezailehaizai
   nipabupa
   woshipale
   ```

6. 查看一下topic信息

   ```bash
   [hadoop@slave2 config]$ kafka-topics.sh -describe --zookeeper master:2181 --topic test
   Topic:test      PartitionCount:1        ReplicationFactor:2     Configs:
           Topic: test     Partition: 0    Leader: 0       Replicas: 2,0   Isr: 0,2
   ```

7. 删除topic

   ```bash
   kafka-topics --delete --zookeeper master:2181 --topic test
   ```

### 关闭Kafka集群

和zookeeper一样, 在所有机器上运行stop脚本

> 比较奇怪的是每个进程关闭的都很慢, 有时候要5s左右.

```bash
[hadoop@slave2 config]$ kafka-server-stop.sh
```

### Kafka集群遇到的单点问题(配置文件已修改)

使用spring boot继承kafka后, producer还是能够正常producer, 但是consumer无法继续消费.

> __consumer_offsets 这个主题下，存储的是所有消费者组消费情况，如果它不是高可用，那自然就无法消费了。

网上查阅似乎是这个topic的问题, 继续进行研究.

```bash
[hadoop@master ~]$ kafka-topics.sh --describe --zookeeper master:2181|grep consumer_offsets
Topic:__consumer_offsets        PartitionCount:50       ReplicationFactor:1     Configs:segment.bytes=104857600,clean                                                 up.policy=compact,compression.type=producer
...
```

发现其ReplicationFactor数量是1, 需要增加副本数量, 不然就会存在单点问题

参考地址: https://www.cnblogs.com/jun1019/p/6634545.html

删除zookeeper上的znode,  具体要删两个地方.

```bash
[hadoop@master ~]$ zkCli.sh
Connecting to localhost:2181
...
[zk: localhost:2181(CONNECTED) 2] rmr /brokers/topics/__consumer_offsets
[zk: localhost:2181(CONNECTED) 4] rmr /config/topics/__consumer_offsets
[zk: localhost:2181(CONNECTED) 5] quit
Quitting...
2019-03-22 14:11:46,987 [myid:] - INFO  [main:ZooKeeper@693] - Session: 0x100021a32890017 closed
2019-03-22 14:11:46,988 [myid:] - INFO  [main-EventThread:ClientCnxn$EventThread@522] - EventThread shut down for session: 0x100021a32890017
[hadoop@master ~]$kafka-topics.sh --describe --topic __consumer_offsets --zookeeper localhost:2181
[hadoop@master ~]$
```

修改配置文件server.properties, 因为版本不一样了, 我修改的部分为下面四项, 三台机器都改一下:

```properties
num.partitions=3
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=3
```

重新启动后, 再创建test的topic, 进行消息生产消费后, 查看__consumer_offsets的情况.

```bash
[hadoop@master logs]$ kafka-topics.sh --describe --topic __consumer_offsets --zookeeper localhost:2181
Topic:__consumer_offsets        PartitionCount:50       ReplicationFactor:3     Configs:segment.bytes=104857600,cleanup.policy=compact,compression.type=producer
...
```

分区变成3个了, 现在关掉两个kafka后测试可用性, 3个kafka任意关掉两个都不会影响消费了,成功.

<span id="Redis集群"></span>

## Redis主从复制, 读写分离, 障碍转移

将Redis的压缩包, 解压到三台机器上, 我固定式解压到/home/study/redis-5.0.3

[三台机器都进行具体配置...记住sentinel.conf的sentinel myid不能一样](https://github.com/huija/CentOSCluster/tree/master/redis-5.0.3_base_settings)  

> 因为在Redis的相关都配置好运行后, 会实时地对配置文件进行修改, 所以我自己都不太记得具体需要配什么了......

其中有一个坑: 因为我是拷贝的三台机器的sentinel.conf, 其中有一个配置项为sentinel myid ....

自动生成了一个myid, 而因为我是机器间互相拷贝的, 所以导致id一样, 导致我总是只能发现一个哨兵, 而redis的障碍转移默认需要两个哨兵发现, 所以一直不成功, 坑死我了.

### 复制, 分离检验

```bash
[study@master redis-5.0.3]$ redis-server redis.conf
16777:C 19 Mar 2019 21:52:39.605 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
16777:C 19 Mar 2019 21:52:39.605 # Redis version=5.0.3, bits=64, commit=00000000, modified=0, pid=16777, just started
16777:C 19 Mar 2019 21:52:39.605 # Configuration loaded
[study@master redis-5.0.3]$ redis-sentinel sentinel.conf
16791:X 19 Mar 2019 21:53:17.160 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
16791:X 19 Mar 2019 21:53:17.160 # Redis version=5.0.3, bits=64, commit=00000000, modified=0, pid=16791, just started
16791:X 19 Mar 2019 21:53:17.160 # Configuration loaded
[study@master redis-5.0.3]$ ps -ef | grep redis
study     16778      1  0 21:52 ?        00:00:00 redis-server 0.0.0.0:6379
study     16792      1  0 21:53 ?        00:00:00 redis-sentinel *:26379 [sentinel]
study     16797  16562  0 21:53 pts/4    00:00:00 grep --color=auto redis
```

三台机器全部启动redis的server和哨兵

```bash
[study@master redis-5.0.3]$ redis-cli -p 6379 info replication
# Replication
role:slave
master_host:192.168.148.130
master_port:6379
master_link_status:up
master_last_io_seconds_ago:0
master_sync_in_progress:0
slave_repl_offset:15735
slave_priority:100
slave_read_only:1
connected_slaves:0
master_replid:4138e22ab14647360f0ec1f286c6775375e82bc2
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:15735
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:15735
```

查看哪一台是master, 这里我进行过障碍转移了, 现在是slave2这台机器是master, master这台机器是slave.

> 后面用master-redis, 来区分到底是redis还是机器

```bash
//在slave2的master-redis进行set操作
127.0.0.1:6379> set demo hhh
OK
127.0.0.1:6379> keys *
1) "demo"
//在master的slave-redis查看是否存在, 如果有尝试set
127.0.0.1:6379> keys *
1) "demo"
127.0.0.1:6379> set demo henghengheng
(error) READONLY You can't write against a read only replica.
```

redis跟postgresql一样, 在这里直接报错, 而不像某某最流行数据库.

### 障碍转移检验

在salve2上面kill掉我们的master-redis.

```bash
[study@slave2 redis-5.0.3]$ ps -ef | grep redis
study     20220      1  0 21:53 ?        00:00:01 redis-server 0.0.0.0:6379
study     20227      1  0 21:53 ?        00:00:01 redis-sentinel *:26379 [sentinel]
study     20414  20179  0 22:00 pts/0    00:00:00 grep --color=auto redis
[study@slave2 redis-5.0.3]$ kill -9 20220
```

已经杀掉了, 去master查看集群状态

```bash
[study@master redis-5.0.3]$ redis-cli -p 6379 info replication
# Replication
role:slave
master_host:192.168.148.130
master_port:6379
master_link_status:down
master_last_io_seconds_ago:-1
master_sync_in_progress:0
slave_repl_offset:97758
master_link_down_since_seconds:28
slave_priority:100
slave_read_only:1
connected_slaves:0
master_replid:4138e22ab14647360f0ec1f286c6775375e82bc2
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:97758
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:97758
```

发现在这个瞬间, master-redis是down了的, 我们等个10s.

```bash
[study@master redis-5.0.3]$ redis-cli -p 6379 info replication
# Replication
role:slave
master_host:192.168.148.129
master_port:6379
master_link_status:up
master_last_io_seconds_ago:0
master_sync_in_progress:0
slave_repl_offset:108487
slave_priority:100
slave_read_only:1
connected_slaves:0
master_replid:9cb87179c96aae91415dc65781344b3a3826db08
master_replid2:4138e22ab14647360f0ec1f286c6775375e82bc2
master_repl_offset:108487
second_repl_offset:97759
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:108487
```

已经障碍转移了, master-redis转到了slave1机器上, 再启动slave2被kill的redis-server, 大概5s后, master-redis已经能够检测到重启的redis了, 重启的redis成为了slave

```bash
[study@slave1 redis-5.0.3]$ redis-cli -p 6379 info replication
# Replication
role:master
connected_slaves:2
slave0:ip=192.168.148.131,port=6379,state=online,offset=141420,lag=1
slave1:ip=192.168.148.130,port=6379,state=online,offset=141570,lag=0
master_replid:9cb87179c96aae91415dc65781344b3a3826db08
master_replid2:4138e22ab14647360f0ec1f286c6775375e82bc2
master_repl_offset:141570
second_repl_offset:97759
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:141570
```

而配置的redis.conf和sentinel.conf是随着集群状况而不断变化的.

### 查看哨兵数目

```bash
[study@master redis-5.0.3]$ redis-cli -h 192.168.148.129 -p 26379 info sentinel
# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=sentinel_one,status=ok,address=192.168.148.129:6379,slaves=2,sentinels=3
```

可以看到集群的状况, 1个master, 2个slave, 3个sentinel.

> 因为在sentinel.conf中设置了sentinel monitor sentinel_one 192.168.148.129 6379 2
>
> 所以必须要2个哨兵发现才可以进行障碍转移.如果只有一个哨兵是不行的.

<span id="环境变量"></span>

## 我的/etc/profile环境变量添加如下

```bash
# root
export PATH=/usr/lib64/qt-3.3/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
## 0.java
export JAVA_HOME=/usr/local/jdk1.8.0_191
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$CLASSPATH:.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
# hadoop
## 1.hadoop
export HADOOP_HOME=/home/hadoop/hadoop-2.7.7
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HADOOP_HOME/lib/native
## 2.zookeeper
export ZOOKEEPER_HOME=/home/hadoop/zookeeper-3.4.13
export PATH=$PATH:$ZOOKEEPER_HOME/bin
## 3.flink
export FLINK_HOME=/home/hadoop/flink-1.7.1
export PATH=$PATH:$FLINK_HOME/bin
export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop
## 4.kafaka
export KAFKA_HOME=/home/hadoop/kafka_2.12-2.1.1
export PATH=$PATH:$KAFKA_HOME/bin
# study
## 1.redis
export REDIS_HOME=/home/study/redis-5.0.3
export PATH=$PATH:$REDIS_HOME/src
# potgres
## postgresql
export PG_HOME=/usr/local/pgsql_10.5
export PATH=$PATH:$PG_HOME/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PG_HOME/lib
export MANPATH=$MANPATH:$PG_HOME/share/man
#export PGDATA=$PG_HOME/data
export PGDATA=/home/postgres/data
export PGLOG=$PGDATA/log
```

