#!/bin/bash

mqtt_topic="mi_temp"
mqtt_ip="192.168.1.60"

sensors_file="sensors"
cel=$'\xe2\x84\x83'
per="%"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Enabling LE Mode"
sudo btmgmt le on

while read -r item; do
    sensor=(${item//,/ })
    mac="${sensor[0]}"
    name="${sensor[1]}"
    echo -e "\n${YELLOW}Sensor: $name ($mac)${NC}"

    RET=1
    until [ ${RET} -eq 0 ]; do
        echo -n "  Getting $name Temperature and Humidity... "
        data=$(/usr/bin/timeout 20 /usr/bin/gatttool -b $mac --char-write-req --handle=0x10 -n 0100 --listen 2>&1 | grep "Notification handle" -m 2)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            echo -e "${RED}failed, waiting 5 seconds before trying again${NC}"
            sleep 5
        else
            echo -e "${GREEN}success${NC}"
        fi
    done

    RET=1
    until [ ${RET} -eq 0 ]; do
        echo -n "  Getting $name Battery Level..."
        battery=$(/usr/bin/gatttool -b $mac --char-read --handle=0x18 2>&1 | cut -c 34-35)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            echo -e "${RED}failed, waiting 5 seconds before trying again${NC}"
            sleep 5
        else
            echo -e "${GREEN}success${NC}"
        fi
    done

    temp=$(echo $data | tail -1 | cut -c 42-54 | xxd -r -p)
    humid=$(echo $data | tail -1 | cut -c 64-74 | xxd -r -p)
    batt=$(echo "ibase=16; $battery"  | bc)
    echo "  Temperature: $temp$cel"
    echo "  Humidity: $humid$per"
    echo "  Battery Level: $batt$per"

    echo -e -n "  Publishing data via MQTT... "
    if [[ "$temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/temperature" -m "$temp"
    fi

    if [[ "$humid" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/humidity" -m "$humid"
    fi

    if [[ "$batt" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/battery" -m "$batt"
    fi
    echo -e "done\n"
done < "$sensors_file"

echo "Finished"