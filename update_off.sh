#!/bin/sh

mysql squid_auth -e 'update state set state=0 where id=1'