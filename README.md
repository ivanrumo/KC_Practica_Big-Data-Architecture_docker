Continuando con el [artículo anterior](https://www.writecode.es/2019-02-25-cluster_hadoop_docker/), en esta ocasión vamos a añadir a nuestro cluster [Hive](https://hive.apache.org/).

Apache Hive sirve para proporcionar agrupación, consulta y análisis de datos. Me resultó curioso descubrir que inicialmente fue un desarrollo de Facebook. Explicándolo de una manera sencilla, Hive nos permite realizar consultas sobre grandes ficheros o conjuntos de datos que se encuentren en un filesystem HDFS de Hadoop. Bueno, también permite trabajar con ficheros en otros sistemas, como por ejemplo, Amazon S3.
Para realizar estos análisis, Hive nos proporciona HiveQL que está basado en SQL. Como vamos a ver más adelante, si controlas de SQL no vas a tener problemas con HiveQL.

Todo los ficheros de esta serie de artículos lo estoy dejando en [este repositorio de Github](https://github.com/ivanrumo/KC_Practica_Big-Data-Architecture_docker). Cada post tiene su propia rama. Para este artículo he creado una rama que se llama [install_hive](https://github.com/ivanrumo/KC_Practica_Big-Data-Architecture_docker/tree/install_hive). Si bajáis con contenido de esa rama tendréis todo listo para probarlo.

Lo que vamos ha hacer es modificar el cluster Hadoop que hicimos para incluir Hive. Luego vamos a generar un par de ficheritos extrayendo datos [del API de stackexchange](https://api.stackexchange.com/). Sobre uno de los ficheros vamos a ejecutar el típico ejemplo de wordcount con MapReduce que incorpora Hadoop y después vamos a lanzar un pequeño Jod de Hive.

Realmente con el volumen de datos que estamos manejando, usar un cluster Hadoop es matar moscas a cañonazos. Me estoy basando en la práctica que realicé en su día donde lo que se buscaba estaba más orientado al tema de arquitectura que de procesamiento de datos. En el siguiente artículo que hablaré de Spark quiero hacer algo con datos más grandes.

# Imágen del nodo master

En el anterior artículo generábamos dos imágenes de Docker. Una para los nodos slave y otra para el nodo master. En el caso de los slaves los mantenemos como están, pero la imagen del master tenemos que modificarla para incluir Hive y algunos ficheros de configuración. Esta era la versión anterior del Docker file de la imagen master.

```yml
WORKDIR /root

ADD config/bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

CMD ["/etc/bootstrap.sh", "-d"]
```

Y este sería nuestro nuevo fichero Dockerfile

```yml
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
```

Como se puede ver los cambios no son muchos.

* Bajamos y descomprimimos el fichero con la versión 2.3.4 de Hive.
* Creamos la variable de entorno HIVE_HOME apuntando a directorio donde hemos instalado Hive y también actualizamos la variable PATH para apuntar a la carpeta bin de Hive.
* Añadimos el fichero hive-site.xml que veremos a continuación.
* Añadimos el fichero hive_job.sql que contiene las sentencias HiveQL para procesar el contenido de los ficheros.
* Y creamos un volumen al directorio /data que utilizaremos para intercambiar ficheros con el host.

Con eso acabaríamos la parte de las imágenes de Docker.

## Configuración de Hive

Este es el contenido del fichero hive-site.xml. En el configuramos el metasore de Hive. En este caso para simplificar lo vamos a dejar con Derby, pero se podría configurar con otro motor de base de datos. Es muy común configurarlo con PostgreSQL.

```xml
<?xml version="1.0"?>
<configuration>
   <property>
      <name>javax.jdo.option.ConnectionURL</name>
      <value>jdbc:derby:;databaseName=/usr/local/hive/metastore_db;create=true</value>
      <description>JDBC connect string for a JDBC metastore.
To use SSL to encrypt/authenticate the connection, provide database-specific SSL flag in the connection URL.
For example, jdbc:postgresql://myhost/db?ssl=true for postgres database.</description>
   </property>
   <property>
      <name>hive.metastore.warehouse.dir</name>
      <value>/user/hive/warehouse</value>
      <description>location of default database for the warehouse</description>
   </property>
   <property>
      <name>hive.metastore.uris</name>
      <value />
      <description>Thrift URI for the remote metastore. Used by metastore client to connect to remote metastore.</description>
   </property>
   <property>
      <name>javax.jdo.option.ConnectionDriverName</name>
      <value>org.apache.derby.jdbc.EmbeddedDriver</value>
      <description>Driver class name for a JDBC metastore</description>
   </property>
   <property>
      <name>javax.jdo.PersistenceManagerFactoryClass</name>
      <value>org.datanucleus.api.jdo.JDOPersistenceManagerFactory</value>
      <description>class implementing the jdo persistence</description>
   </property>
</configuration>
```

## Script de lanzamiento del nodo master

El script de inicio de la imagen docker también lo he modificado (bootstrap.sh). Anteriormente se iniciaba el DFS y el YANR del cluster. Ahora realiza algunas tareas mas:

* Crea en HDFS las rutas de entrada y copia los ficheros.
* Crean en HDFS las rutas que se han configurado en el fichero hive-site.xml.
* Se inicializa el schema del metastorage de Hive
* Se ejecuta un trabajo de MapReduce que realiza un wordcount del fichero input_answers.
* Se ejecuta el job de Hive.
* Copia los resultados de la ejecución del job Hive en /data para que puedan leerse y analizarse desde fuera del cluster de Docker.

```sh
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
$HIVE_HOME/bin/hive -f /root/hive_job.sql

# copy results from hdfs to local
$HADOOP_HOME/bin/hdfs dfs -copyToLocal /user/root/users_most_actives /data
$HADOOP_HOME/bin/hdfs dfs -copyToLocal /user/root/locations_most_actives /data
```

## Script de lanzamiento de Cluster

El script start-cluster.sh, al igual que en el artículo anterior, es que el hace que suceda toda la magia. Pero ahora realiza algunas acciones más:

* Ejecuta el script de Python que extrae los datos del API de Stackexchange. Más adelante comento las acciones que realiza el scrip en mas detalle.
* Al igual que hacía anteriormente, genera las imágenes de Docker, crea los contenedores de los nodos slave y del nodo master y los lanza.
* Una vez lanzados espera a que se termine la ejecución de los jobs. Para ello espera hasta que exista la carpeta data/locations_most_actives que es donde se dejan los resultados del job de Hive.
* Por último para los nodos del cluster.

```bash
#!/bin/bash

# provisioning data
rm data/user_ids_names &> /dev/null
python src/provisioning_data.py

sudo rm -rf data/locations_most_actives data/users_most_actives

# create base hadoop cluster docker image
docker build -f docker/base/Dockerfile -t irm/hadoop-cluster-base:latest docker/base

# create master node hadoop cluster docker image
docker build -f docker/master/Dockerfile -t irm/hadoop-cluster-master:latest docker/master

echo "Starting cluster..."

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
#docker exec -it hadoop-master bash

echo "Making jobs. Please wait"

while [ ! -d data/locations_most_actives ]
do
  sleep 10
  #echo "Waiting..."
done

echo "Stoping cluster..."
docker stop hadoop-master

i=1
while [ $i -lt $N ]
do
	docker stop hadoop-slave$i
	
	i=$(( $i + 1 ))
done 
```

## Script de Python

El script de Python necesita el paquete requests para realizar las llamadas al API de Stackexchange:

```bash
pip install requests
```

El script provisioning_data.py utiliza dos llamadas del API.

1. **answers**: Con esta endpoint obtenemos las respuestas realizadas a preguntas. La idea es obtener todas las respuestas realizadas para obtener los usuarios más activos ayudando a los demás. Para ello grabamos el nombre del usuario que ha realizado la respuesta en una línea del fichero **data/user_ids_answers**. Sobre este fichero se realizará posteriormente el proceso MapReduce de wordcount para obtener el número de respuestas que ha realizado cada usuario.
2. **users**: Por cada usuario que hemos obtenido realizamos una llamada a este endpoint para obtener de cada usuario su user_id, display_name, reputation y location. Estos datos los grabamos separados por comas en el fichero **data/user_ids_names**. Este fichero se tratará en el Job de hive que se lanza en el cluster.

```python
import requests

from datetime import datetime, timedelta
import time
import os

# obtenemos la fecha de hace 1 dia
d = datetime.today() - timedelta(days=1)

fromdate = int(d.timestamp())

url_base = "https://api.stackexchange.com/2.2/answers?&order=asc&sort=activity&site=stackoverflow&pagesize=100&fromdate=" + str(
    fromdate)
print(url_base)
has_more = True
pagina = 1


with open('data/user_ids_answers', 'w') as f_user_ids_answers:
    while (has_more):
        url_request = url_base + "&page=" + str(pagina)
        response = requests.get(url_request)

        result = response.json()

        if (result.get('error_id')):
            print("Error: " + result.get('error_message'))
            break;

        for answer in result['items']:
            owner = answer['owner']
            if (owner.get('user_id')):  # algunas peticiones no traen el user_id
                f_user_ids_answers.write(str(answer['owner']['user_id']) + "\n")
                #print(str(answer['owner']['user_id']) + "\n")

        print(end=".")
        #print("request")

        has_more = result['has_more']
        pagina = pagina + 1
        time.sleep(1)


with open('data/user_ids_answers', 'r') as f_user_ids_answers:
    # El API de stackexchange nos permite
    # https://api.stackexchange.com/docs/users-by-ids

    i = 0
    users_url = ""
    for user_id in f_user_ids_answers:
        user_id = f_user_ids_answers.readline().rstrip()

        if (i >= 100):
            # quitamos el ultimo ; y hacemos la peticion para obtener los datos de los usuarios
            users_url = users_url[:-1]
            url = "https://api.stackexchange.com/2.2/users/" + users_url + "?pagesize=100&order=desc&sort=reputation&site=stackoverflow"
            # print(url)
            print(end=".")
            response = requests.get(url)
            result = response.json()

            with open('data/user_ids_names', 'a') as f_user_ids_names:
                if (result.get('error_id')):
                    print("Error: " + result.get('error_message'))
                else:
                    for user in result['items']:
                        user_id = user['user_id']
                        name = user.get('display_name')
                        reputation = user.get('reputation')
                        location = user.get('location')
                        f_user_ids_names.write(
                            str(user_id) + "," + name + "," + str(reputation) + "," + str(location) + "\n")

            i = 0
            users_url = ""

        users_url = users_url + str(user_id) + ";"
        i = i + 1
```

## El job de Hive

Como he comentado anteriormente, para el volumen de datos que se manejan en este artículo, montar un cluster de Hadoop es matar moscas a cañonazos. Pero para poder entrever el potencial del software nos vale. Ahora imagina que en vez de 200 KB de datos, los ficheros de entrada fueran de 200 GB o 200 TB. Un cluster de Hadoop nos permitiría repartir la carga de trabajo entre todos los nodos del cluster. Estos pequeños ficheros los procesa en pocos segundos, pero si fueran de ese tamaño nos llevaría mucho más tiempo procesarlos. Pues en vez de ejecutarlos en tu portátil imagina que te proporcionan cinco buenas máquinas en tu empresa para montar el cluster. El tiempo de procesamiento, al tener cinco buenas máquinas en el cluster, se reduciría bastante. Ahora imagina que en vez de tener el hiero en tu empresa te dan acceso a la nube de Amazon, Google o Microsoft y en vez de cinco nodos, el cluster puede tener cincuenta. El tiempo se reduciría bastante más. Así esta lo bueno de esto. Y cuando llegue a Spark que ejecuta este tipo de procesos más rápido todavía mejor.

Dicho esto, este es el contenido del fichero hive_job.sql:

```sql
CREATE TABLE IF NOT EXISTS users
(user_id INT, name STRING, reputation INT, location STRING)
row format delimited fields terminated by ',';

LOAD DATA INPATH '/user/root/input_names/user_ids_names' INTO TABLE users;

CREATE TABLE IF NOT EXISTS user_answers
(user_id INT, n_answers INT) row format delimited fields terminated by '\t';

LOAD DATA INPATH '/user/root/output/*' INTO TABLE user_answers;

CREATE EXTERNAL TABLE IF NOT EXISTS users_most_actives(
user_id INT, name STRING, n_answers INT) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE 
LOCATION '/user/root/users_most_actives';

INSERT OVERWRITE TABLE users_most_actives SELECT DISTINCT users.user_id, users.name, user_answers.n_answers  
FROM users JOIN user_answers ON users.user_id = user_answers.user_id  
ORDER BY n_answers DESC;

CREATE EXTERNAL TABLE IF NOT EXISTS localtions_most_actives( 
location STRING, n_answers INT)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/root/locations_most_actives';

INSERT OVERWRITE TABLE localtions_most_actives SELECT location, SUM(user_answers.n_answers) TOTAL 
FROM users JOIN user_answers ON users.user_id = user_answers.user_id  
GROUP BY location
ORDER BY TOTAL DESC;
```

Si tienen conocimientos de SQL no creo que te cueste mucho seguir la ejecución de este script.

* Primero creo las tablas users y user_answers. La primera la carga con los datos del fichero user_ids_names obtenido en el script de Python. La segunda se carga con los ficheros de salida del proceso de wordcount.
* Luego se crea la tabla users_most_actives donde obtendremos los usuarios más activos. Esta es una tabla externa y los registros que se inserten en ella se grabaran el la ruta HDFS /user/root/users_most_actives.
* A continuación insertamos los registros de esta tabla realizando una consulta sobre las tablas users y user_answers
* Con la tabla localtions_most_actives realizamos un proceso similar. También es una tabla externa que se guardará en la ruta HDFS /user/root/locations_most_actives. En esta tabla vamos a guardar las localidades mas más respuestas realizadas. Al igual que con la otra tabla externa, los datos los obtenemos de las tablas users y user_answers.

Como se puede ver, a partir de unos ficheros obtenemos unos datos que pueden tener valor. A lo mejor para una empresa de recruiting realizar unos procesos similares, pero mucha más información podrían ser interesantes. Al final, en esto del Big Data, lo importante es tener muchos datos para luego tratarlos y analizarlos para obtener información de valor.

