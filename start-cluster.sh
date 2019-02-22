#!/bin/bash

# create base hadoop cluster docker image
docker build -f docker/base/Dockerfile -t irm/hadoop-cluster-base:latest docker/base

# create master node hadoop cluster docker image
docker build -f docker/master/Dockerfile -t irm/hadoop-cluster-master:latest docker/master


# the default node number is 3
N=${1:-3}

docker network create --driver=bridge hadoop &> /dev/null

# start hadoop slave container
i=1
while [ $i -lt $N ]
do
	docker rm -f hadoop-slave$i &> /dev/null
	echo "start hadoop-slave$i container..."
	docker run -itd \
	                --net=hadoop \
	                --name hadoop-slave$i \
	                --hostname hadoop-slave$i \
	                irm/hadoop-cluster-base
	i=$(( $i + 1 ))
done 



# start hadoop master container
docker rm -f hadoop-master &> /dev/null
echo "start hadoop-master container..."
docker run -itd \
                --net=hadoop \
                -p 50070:50070 \
                -p 8088:8088 \
                --name hadoop-master \
                --hostname hadoop-master \
				-v $PWD/data:/data \
                irm/hadoop-cluster-master



# get into hadoop master container
docker exec -it hadoop-master bash
