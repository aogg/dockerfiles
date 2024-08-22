#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log

# 只有pgyvpn
(sleep 2 && tail -f /var/log/oray/pgyvpn/pgyvistor.log | awk '{print "/var/log/oray/pgyvpn/pgyvistor.log--文件输出: " $0}') &
(sleep 2 && tail -f /var/log/oray/pgyvpn_svr/pgyvpnsvr.log | awk '{print "/var/log/oray/pgyvpn_svr/pgyvpnsvr.log--文件输出: " $0}') &

service pgyvpn start
sleep 1
pgyvisitor login -u ${PGY_USERNAME} -p ${PGY_PASSWORD}

while true
do 
        sleep 60
done



