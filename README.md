Auth squid by query to oracle and cache result to mysql

git clone 
chown proxy -R squid-auth-db-cache


#1 Install perl libs

apt-get install build-essential default-libmysqlclient-dev`
export ORACLE_HOME=/opt/oracle/instantclient_21_5 
cpan install DBI  Config::Simple CPAN::DistnameInfo LWP Test::NoWarnings DBD:Orable`


mysql 
 create database squid_auth;
 CREATE USER 'squid'@'localhost' IDENTIFIED BY '123';
 GRANT ALL PRIVILEGES ON squid_auth.* TO 'squid'@'localhost';
 FLUSH PRIVILEGES;


# mysql squid_auth <init.sql
