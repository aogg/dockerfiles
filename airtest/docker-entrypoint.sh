#!/usr/bin/env bash


# @see https://github.com/appium/appium-docker-android/blob/master/Appium/start.sh
# It is workaround to access adb from androidusr
echo "Prepare adb to have access to device"
adb devices >/dev/null
#  chown -R 1300:1301 .android
echo "adb can be used now"


# Connect device via wireless
# if [ "${REMOTE_ADB}" = true ]; then
# 	echo "Connect device via wireless"
# 	# Avoid lost connection
# 	/wireless_autoconnect.sh && \
# 	/wireless_connect.sh
# fi



$@

# adb disconnect ${array_device}

echo '-------------容器结束-----------------------------'