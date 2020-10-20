#!/usr/bin/env bash 

if [[ ! -d /etc/nginx/logs ]];then
  ln -sf /var/log/nginx/ /etc/nginx/logs
fi

/usr/local/openresty/bin/openresty -p /etc/nginx/ -c /etc/nginx/nginx.conf -g "daemon off;"


