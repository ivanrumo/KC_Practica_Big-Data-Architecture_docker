#!/bin/bash

service ssh start

# start cluster
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh 

# start spark history server
$SPARK_HOME/sbin/start-history-server.sh

# create paths and give permissions
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root/input_answers
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root/input_names
$HADOOP_HOME/bin/hdfs dfs -copyFromLocal /data/user_ids_answers input_answers
$HADOOP_HOME/bin/hdfs dfs -copyFromLocal /data/user_ids_names input_names
$HADOOP_HOME/bin/hdfs dfs -mkdir /spark-logs

# run the spark job

# copy results from hdfs to local
$HADOOP_HOME/bin/hdfs dfs -copyToLocal /user/root/users_most_actives /data
$HADOOP_HOME/bin/hdfs dfs -copyToLocal /user/root/locations_most_actives /data

bash