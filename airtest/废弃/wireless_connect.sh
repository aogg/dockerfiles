#!/usr/bin/bash

# @see https://github.com/appium/appium-docker-android/blob/master/Appium/wireless_connect.sh

adbSh=${ADB_PATH:-adb}

if [ ! -z "${ANDROID_DEVICES}" ]; then
	IFS=',' read -r -a array <<<"${ANDROID_DEVICES}"
	for i in "${!array[@]}"; do
		array_device=$(echo ${array[$i]} | tr -d " ")
		#string contains check
		if [[ ${connected_devices} != *${array_device}* ]]; then
			echo "Connecting to: ${array_device}"
			$adbSh connect ${array_device} >/dev/null 2>/dev/null
			#Give time to finish connection
			sleep 2
			$adbSh devices
			echo "Success!"
		fi
	done
fi