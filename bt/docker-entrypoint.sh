#!/usr/bin/env bash 


if [ -d "/www" ] && [ "$(ls -A /www)" ]; then
    echo "www not empty"
else
    echo "www is empty"
    cp -a /www_bak/* /www
fi

bt restart

tail -f /www/server/panel/logs/*.log