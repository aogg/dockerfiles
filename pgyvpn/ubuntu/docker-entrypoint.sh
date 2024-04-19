#!/usr/bin/env bash


mkdir -p /var/log/oray/
touch /var/log/oray/pgyvpn/pgyvistor.log

(sleep 2 && tail -f /var/log/oray/pgyvpn/pgyvistor.log) &

service pgyvpn start
sleep 1
pgyvisitor login -u ${PGY_USERNAME} -p ${PGY_PASSWORD}

while true
do 
        sleep 60
done



