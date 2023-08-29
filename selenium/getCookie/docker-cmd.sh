#!/usr/bin/env bash

export APP_ARGS="--start-maximized --remote-debugging-port=1234 ${URL}"

/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait &

wget -O /getCookie/stealth.min.js https://raw.githubusercontent.com/requireCool/stealth.min.js/main/stealth.min.js & 
sleep 5

exec python3 /getCookie/getCookie.py 2>&1


