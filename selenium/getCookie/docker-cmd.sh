#!/usr/bin/env bash

export APP_ARGS="--start-maximized --remote-debugging-port=1234 ${URL}"

wget -t 1 -O /getCookie/stealth.min.js https://raw.githubusercontent.com/requireCool/stealth.min.js/main/stealth.min.js & 

(/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait) &

sleep 5

ps -ef
echo "开始执行------getCookie.py"
exec python3 /getCookie/getCookie.py 2>&1


