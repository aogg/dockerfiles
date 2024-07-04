#!/usr/bin/env bash

export APP_ARGS="--start-maximized --remote-debugging-port=1234 ${URL}"

wget -t 1 -O /getCookie/stealth.min.js https://raw.githubusercontent.com/requireCool/stealth.min.js/main/stealth.min.js & 

(/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait) &

# sleep 7

while true; do
  if ps -ef | grep -v grep | grep -q xiccd; then
    echo "xiccd 进程已经在运行"
    
    sudo ps -ef > /tmp/ps
    cat /tmp/ps

    echo "开始执行------getCookie.py"
    exec python3 /getCookie/getCookie.py 2>&1

    break  # 执行成功后跳出循环
  else
    echo "xiccd 进程未找到"
    sleep 1  # 等待一秒后继续循环
  fi
done



