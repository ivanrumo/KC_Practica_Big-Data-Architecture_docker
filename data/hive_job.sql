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
