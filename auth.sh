#!/bin/sh
#logger 'Starting auth squid'
curdir=`dirname "$(readlink -f "$0")"`
export ORACLE_HOME=/opt/instantclient_21_5
cd $curdir
perl -w $curdir/auth.pl