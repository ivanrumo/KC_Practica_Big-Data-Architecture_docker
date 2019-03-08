FROM irm/hadoop-cluster-base
MAINTAINER irm

WORKDIR /root

RUN wget http://apache.rediris.es/hive/hive-2.3.4/apache-hive-2.3.4-bin.tar.gz && \
    tar xvf apache-hive-2.3.4-bin.tar.gz && \
    mv apache-hive-2.3.4-bin /usr/local/hive && \
    rm apache-hive-2.3.4-bin.tar.gz

ENV HIVE_HOME=/usr/local/hive
ENV PATH=$PATH:/usr/local/hive/bin

ADD config/hive-site.xml /usr/local/hive/conf/hive-site.xml
RUN chown root:root /usr/local/hive/conf/hive-site.xml

ADD config/bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ADD config/hive_job.sql /root/hive_job.sql


ENV BOOTSTRAP /etc/bootstrap.sh

VOLUME /data

CMD ["/etc/bootstrap.sh", "-d"]

