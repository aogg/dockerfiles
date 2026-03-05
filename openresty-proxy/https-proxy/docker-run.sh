#!/bin/ash

sed -i -e "s%--client_max_body_size--%`echo $CLIENT_MAX_BODY_SIZE`%g" /etc/nginx/conf.d/lua.https.proxy.conf
sed -i -e "s%--proxy_timeout--%`echo $PROXY_TIMEOUT`%g" /etc/nginx/conf.d/lua.https.proxy.conf



exec /usr/local/openresty/bin/openresty -g "daemon off;"