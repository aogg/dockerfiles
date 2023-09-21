#!/usr/bin/env bash



if [ -f "/vpn/vpn.conf" ];then
  wget -O /vpn/vpn.conf $DOCKOVPN_SERVER:8080
fi

# 需要tcp
# http-proxy 192.168.4.1 1080
if [ -z "$HTTP_PROXY" ];then
  echo "http-proxy $HTTP_PROXY" >> /vpn/vpn.conf
fi

exec /usr/bin/openvpn.sh
