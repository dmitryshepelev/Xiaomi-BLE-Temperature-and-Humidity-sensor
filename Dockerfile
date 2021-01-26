FROM ubuntu:18.04 AS base

RUN apt-get update && apt-get install -y mosquitto-clients bc bluez xxd cron vim

COPY ./cron_conf /etc/cron.d/cron_conf
RUN chmod 0644 /etc/cron.d/cron_conf && crontab /etc/cron.d/cron_conf && touch /var/log/cron.log

COPY ./sensors /opt/sensors

WORKDIR ./program
COPY ./mi_temp.sh ./
RUN ln -s $(pwd)/mi_temp.sh /opt/mi_temp

CMD cron && tail -f /var/log/cron.log
