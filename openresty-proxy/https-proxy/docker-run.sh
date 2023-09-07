#!/bin/ash

sed -i -e "s%--client_max_body_size--%`echo $CLIENT_MAX_BODY_SIZE`%g" /etc/nginx/conf.d/default.conf
sed -i -e "s%--default_proxy_pass--%`echo $DEFAULT_PROXY_PASS`%g" /etc/nginx/conf.d/default.conf



exec /usr/local/openresty/bin/openresty -g "daemon off;"