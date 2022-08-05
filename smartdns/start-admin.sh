#!/bin/sh

touch /smartdns.resolv.conf;
sed -i -e "s%--logLevel--%`echo $LOG_LEVEL`%g" /config-admin.conf

# currentDns=$(nslookup localhost|grep Server|awk '{print $2}');
# serverString=$(cat /etc/resolv.conf|grep nameserver| sed -e 's/nameserver/server /g')
# sed -i -e "s%#--/etc/resolv.conf--%`echo -e "$serverString"`%g" /config-admin.conf

#--/etc/resolv.conf--
cat /etc/resolv.conf|grep nameserver| sed -e 's/nameserver/server /g' > /smartdns.resolv.conf

/bin/smartdns -f -x -c /config-admin.conf
