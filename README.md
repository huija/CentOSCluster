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


