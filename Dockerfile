FROM ubuntu:18.04 AS base

RUN apt-get update && apt-get install -y mosquitto-clients bc bluez xxd cron vim

#COPY ./cron_conf /etc/cron.d/cron_conf
#RUN chmod 0644 /etc/cron.d/cron_conf && crontab /etc/cron.d/cron_conf

COPY ./sensors /opt/sensors

WORKDIR ./program
COPY ./*.sh ./
RUN ln -s $(pwd)/mi_temp.sh /opt/mi_temp && chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
