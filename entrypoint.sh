#!/bin/bash

printenv | sed 's/^\(.*\)$/export \1/g' | grep "BROKER_" > /root/.env

echo "SHELL=/bin/bash
BASH_ENV=/root/.env
*/1 * * * * /opt/mi_temp | tee /tmp/mi_temp > /proc/1/fd/1 2>/proc/1/fd/2
#" > /etc/cron.d/cron_conf

crontab /etc/cron.d/cron_conf
cron -f

exec "$@"
