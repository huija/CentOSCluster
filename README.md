# CentOSCluster
Hadoop,Zookeeper,Flink等集群配置

## 虚拟机
OS:Centos7三台  
master一台,slave两台.  
>1.后面会配置HA,这只是个hostname.  
每台机器配置下hosts文件.  
2.创建hadoop用户并配置sudo  
为了各软件管理方便,一律放在/home/hadoop目录下,以hadoop用户进行操作.  
3.切换hadoop用户在/home/hadoop下设置ssh免密,关闭防火墙,并关闭Selinux!  

## hadoop2.7.7基本配置
按照[hadoop基本配置](https://github.com/huija/CentOSCluster/tree/master/hadoop2.7.7_base_settings),修改相关hostname及路径,放到你的配置文件夹中.然后启动你的hadoop集群:  
``` bash
hdfs namenode -format
start-dfs.sh
start-yarn.sh
```
jps查看启动进程
>master上:NameNode,SecondaryNameNode,ResourceManager  
slaves上:DataNode,NodeManager

或者直接在浏览器访问hdfs和yarn管理台:
>master:8080和master:50070

关闭集群:
``` bash
stop-yarn.sh
stop-dfs.sh
```