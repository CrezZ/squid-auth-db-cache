#!/bin/sh

mysql squid_auth -e 'update state set state=1 where id=1'

