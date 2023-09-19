#!/usr/bin/env bash




# Connect device via wireless
if [ "${REMOTE_ADB}" = true ]; then
	echo "Connect device via wireless"
	# Avoid lost connection
	/wireless_autoconnect.sh && \
	/wireless_connect.sh
fi



exec $@