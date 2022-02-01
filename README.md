# squid-auth-db-cache

Auth squid by query to oracle and cache result to mysql

git clone 
chown proxy -R squid-auth-db-cache

# Install Oracle instant client

copy links from https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html
we need "Basic Package" and "SqlPlus"
```
cd /opt
mkdir oracle
cd oracle`
wget https://download.oracle.com/otn_software/linux/instantclient/215000/instantclient-basic-linux.x64-21.5.0.0.0dbru.zip
wget https://download.oracle.com/otn_software/linux/instantclient/215000/instantclient-sqlplus-linux.x64-21.5.0.0.0dbru.zip
unzip instantclient*.zip
rm *.zip
echo /opt/oracle/instantclient_21_5 >/etc/ld.conf.d/oracle_client.conf
/sbin/ldconfig
echo 'export ORACLE_HOME=/opt/oracle/instantclient_21_5' >/etc/profile.d/oracle.sh
```

# Install perl libs
```
apt-get install build-essential default-libmysqlclient-dev
export ORACLE_HOME=/opt/oracle/instantclient_21_5 
cpan install DBI  Config::Simple CPAN::DistnameInfo LWP Test::NoWarnings DBD:Orable Log::Any
```

# Init mysql

```
mysql -e '
 create database squid_auth;
 CREATE USER 'squid'@'localhost' IDENTIFIED BY '123';
 GRANT ALL PRIVILEGES ON squid_auth.* TO 'squid'@'localhost';
 FLUSH PRIVILEGES;
'
 mysql squid_auth <init.sql
```

