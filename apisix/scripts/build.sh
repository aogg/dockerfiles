#!/usr/bin/env ash 

# @see https://github.com/apache/apisix-dashboard/blob/v1.5/api/build.sh

pwd=`pwd`

sed -i -e "s%#mysqlAddress#%`echo $MYSQL_SERVER_ADDRESS`%g" ${pwd}/conf.json
sed -i -e "s%#mysqlUser#%`echo $MYSQL_USER`%g" ${pwd}/conf.json
sed -i -e "s%#mysqlPWD#%`echo $MYSQL_PASSWORD`%g" ${pwd}/conf.json
sed -i -e "s%#syslogAddress#%`echo $SYSLOG_HOST`%g" ${pwd}/conf.json
sed -i -e "s%#apisixBaseUrl#%`echo $APISIX_BASE_URL`%g" ${pwd}/conf.json
sed -i -e "s%#apisixApiKey#%`echo $APISIX_API_KEY`%g" ${pwd}/conf.json

# dashboard的登录和账号密码
sed -i -e "s%#apisixDashboardUsername#%`echo ${APISIX_DASHBOARD_USERNAME:-admin}`%g" ${pwd}/conf.json
sed -i -e "s%#apisixDashboardPassword#%`echo ${APISIX_DASHBOARD_PASSWORD:-admin}`%g" ${pwd}/conf.json


mkdir -p /go/src/github.com/apisix/manager-api/conf
cp -a ${pwd}/conf.json /go/src/github.com/apisix/manager-api/conf

cd /root/manager-api
exec ./manager-api
