#!/bin/bash
postgres="postgres"
dbname="ranger"
password="D0n0tcr4ck"
rangerdba="rangerdba"

rpm -qa | grep sudo 2>&1 > /dev/null
 
if [ $? -ne 0 ]; then
	yum -y install sudo
fi

ls /usr/share/java/postgresql-jdbc.jar 2>&1 > /dev/null

if [ $? -ne 0 ]; then
	yum -y install postgresql-jdbc*
fi

ls /usr/share/java/postgresql-jdbc.jar 2>&1 /dev/null

if [ $? -ne 0 ]; then
	echo "failed to install postgres jdbc jar"
	exit 1
fi

chmod 644 /usr/share/java/postgresql-jdbc.jar


echo "CREATE DATABASE $dbname;" | sudo -u $postgres psql -U postgres -v "ON_ERROR_STOP=1"

if [ $? -ne 0 ]; then
	echo "failed to create database $dbname"
	exit 1
fi

echo "CREATE USER $rangerdba WITH PASSWORD '$password';" | sudo -u $postgres psql -U postgres -v "ON_ERROR_STOP=1"

if [ $? -ne 0 ]; then 
	echo "failed to create $rangerdba user"
	exit 1
fi

echo "GRANT ALL PRIVILEGES ON DATABASE $dbname TO $rangerdba;" | sudo -u $postgres psql -U postgres -v "ON_ERROR_STOP=1"

if [ $? -ne 0 ]; then
	echo "failed to grant privilege to $rangerdba on $dbname database"
	exit 1
fi

ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar

if [ $? -ne 0 ]; then
	echo "failed to setup ambari jdbc postgres"
	exit 1
fi

export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:${JAVA_JDBC_LIBS}:/connector jar path

cat  <<EOF > /var/lib/pgsql/data/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all   postgres                                     peer
# IPv4 local connections:
host    all   postgres             127.0.0.1/32            ident
# IPv6 local connections:
host    all   postgres             ::1/128                 ident
# Allow replication connections from localhost, by a user with the
# replication privilege.
#local   replication     postgres                                peer
#host    replication     postgres        127.0.0.1/32            ident
#host    replication     postgres        ::1/128                 ident

local  all  ambari,mapred,rangerdba md5
host  all   ambari,mapred,rangerdba 0.0.0.0/0  md5
host  all   ambari,mapred,rangerdba ::/0 md5
EOF

if [ $? -ne 0 ]; then
        echo "failed to modify pg_hba"
        exit 1
fi

sudo -u postgres /usr/bin/pg_ctl -D /var/lib/pgsql/data reload
