#!/bin/bash


rm /tmp/*.pid


service ssh start
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh 

sleep 30

hdfs dfs -mkdir -p input

# put input files to HDFS
hdfs dfs -put /data/* input

# run wordcount 
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/sources/hadoop-mapreduce-examples-2.7.7-sources.jar org.apache.hadoop.examples.WordCount input/user_ids_answers output

if [[ $1 == "-d" ]]; then
#    while true; do sleep 1000; done
fi

if [[ $1 == "-bash" ]]; then
#    /bin/bash
fi
