#!/bin/bash

service ssh start

# start cluster
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh 

# create paths and give permissions
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root/input_answers
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root/input_names
$HADOOP_HOME/bin/hdfs dfs -copyFromLocal /data/user_ids_answers input_answers
$HADOOP_HOME/bin/hdfs dfs -copyFromLocal /data/user_ids_names input_names

$HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hive/warehouse
$HADOOP_HOME/bin/hdfs dfs -mkdir /tmp

$HADOOP_HOME/bin/hdfs dfs -chmod g+w /user/hive/warehouse
$HADOOP_HOME/bin/hdfs dfs -chmod g+w /tmp

# init hive metastorage
$HIVE_HOME/bin/schematool -dbType derby -initSchema

# launch wordcount job
$HADOOP_HOME/bin/hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.7.jar wordcount input_answers output

# launch hive job
$HIVE_HOME/bin/hive -f /data/hive_job.sql

# copy results from hdfs to local
$HADOOP_HOME/bin/hdfs dfs -copyToLocal /user/root/users_most_actives /data
$HADOOP_HOME/bin/hdfs dfs -copyToLocal /user/root/locations_most_actives /data

bash