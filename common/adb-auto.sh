#!/bin/sh

# 定义多个IP和端口，使用逗号分隔
# ip_ports="192.168.1.1:5555,192.168.1.2:5555,192.168.1.3:5555"
ip_ports=$ANDROID_DEVICES

# 将字符串按逗号分割成数组
IFS=',' read -r -a ip_port_array <<< "$ip_ports"

# 循环连接每个IP:端口
# for ip_port in "${ip_port_array[@]}"
# do
#     adb connect "$ip_port"
# done

# 循环检测连接是否断开，间隔REMOTE_ADB_POLLING_SEC秒
# REMOTE_ADB_POLLING_SEC=10
while true
do
    for ip_port in "${ip_port_array[@]}"
    do
        adb devices | grep "$ip_port" > /dev/null
        if [ $? -ne 0 ]; then
            echo "连接 $ip_port 断开"
            adb connect "$ip_port"
        fi
    done
    sleep $ADB_SLEEP_SEC
done