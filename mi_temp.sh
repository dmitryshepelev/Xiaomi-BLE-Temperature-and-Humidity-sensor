#!/bin/bash

mqtt_topic="sensors"
mqtt_ip="162.30.0.103"

sensors_file="/opt/sensors"

cel=$'\xe2\x84\x83'
per="%"

red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
nc='\033[0m'

script_name="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

lock_file="/var/tmp/$script_name"
if [ -e "${lock_file}" ] && kill -0 "$(cat "${lock_file}")"; then
    echo 'exit'
    exit 99
fi

trap 'rm -f "${lock_file}"; exit' INT TERM EXIT
echo $$ > "${lock_file}"

echo "Opening and initializing HCI device"
hciconfig hci0 up
echo "Enabling LE Mode"
btmgmt le on

while read -r item; do
    sensor=(${item//,/ })
    mac="${sensor[0]}"
    name="${sensor[1]}"
    echo -e "\n${yellow}Sensor: $name ($mac)${nc}"

    exit_code=1
    until [ ${exit_code} -eq 0 ]; do
        echo -n "  Getting $name Temperature and Humidity... "
        data=$(timeout 30 /usr/bin/gatttool -b "$mac" --char-write-req --handle=0x10 -n 0100 --listen 2>&1 | grep -m 1 "Notification")
        exit_code=$?
        if [ ${exit_code} -ne 0 ]; then
            echo -e "${red}failed, waiting 5 seconds before trying again${nc}"
            sleep 5
        else
            echo -e "${green}success${nc}"
        fi
    done

    exit_code=1
    until [ ${exit_code} -eq 0 ]; do
        echo -n "  Getting $name Battery Level..."
        battery=$(/usr/bin/gatttool -b "$mac" --char-read --handle=0x18 2>&1 | cut -c 34-35)
        battery=${battery^^}
        exit_code=$?
        if [ ${exit_code} -ne 0 ]; then
            echo -e "${red}failed, waiting 5 seconds before trying again${nc}"
            sleep 5
        else
            echo -e "${green}success${nc}"
        fi
    done
    temp=$(echo "$data" | tail -1 | cut -c 42-54 | xxd -r -p)
    humid=$(echo "$data" | tail -1 | cut -c 64-74 | xxd -r -p)
    batt=$(echo "ibase=16; $battery"  | bc)
    dewp=$(echo "scale=1; (243.12 * (l( $humid / 100) +17.62* $temp/(243.12 + $temp)) / 17.62 - (l( $humid / 100) +17.62* $temp/(243.12 + $temp))  )" | bc -l)
    if [[ "dewp" < -20 ]]; then
	dewp=-20
    fi
    datetime=`date +"%D %T"`
    
    echo "  Temperature: $temp$cel"
    echo "  Humidity: $humid$per"
    echo "  Battery Level: $batt$per"
    echo "  Dew Point: $dewp$cel"
    echo "  Time: $datetime"

    echo -e -n "  Publishing data via MQTT... "
    if [[ "$temp" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/temperature" -m "$temp" -u ${BROKER_USERNAME} -P ${BROKER_PASSWORD}
    fi

    if [[ "$humid" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/humidity" -m "$humid" -u ${BROKER_USERNAME} -P ${BROKER_PASSWORD}
    fi

    if [[ "$batt" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/battery" -m "$batt" -u ${BROKER_USERNAME} -P ${BROKER_PASSWORD}
    fi
    
    if [[ "$dewp" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/dewpoint" -m "$dewp" -u ${BROKER_USERNAME} -P ${BROKER_PASSWORD}
    fi
    /usr/bin/mosquitto_pub -h $mqtt_ip -V mqttv311 -t "/$mqtt_topic/$name/datetime" -m "$datetime" -u ${BROKER_USERNAME} -P ${BROKER_PASSWORD}
    echo -e "done"
done < "$sensors_file"

#echo -e "\nclosing HCI device"
#sudo hciconfig hci0 down

echo "Finished"
