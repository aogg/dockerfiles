#!/bin/sh

pwd=`pwd`

# config
cp ${pwd}/api/conf/conf_preview.json ${pwd}/conf.json

# export APIX_DAG_LIB_PATH="${pwd}/dag-to-lua-1.1/lib/"
# export APIX_ETCD_ENDPOINTS="127.0.0.1:2379"

export SYSLOG_HOST=${SYSLOG_HOST:-127.0.0.1}

if [[ "$unamestr" == 'Darwin' ]]; then
	sed -i '' -e "s%#syslogAddress#%`echo $SYSLOG_HOST`%g" ${pwd}/conf.json
else
	sed -i -e "s%#syslogAddress#%`echo $SYSLOG_HOST`%g" ${pwd}/conf.json
fi

# dashboard的登录和账号密码
sed -i -e "s%#apisixDashboardUsername#%`echo ${APISIX_DASHBOARD_USERNAME:-admin}`%g" ${pwd}/conf.json
sed -i -e "s%#apisixDashboardPassword#%`echo ${APISIX_DASHBOARD_PASSWORD:-admin}`%g" ${pwd}/conf.json


cp ${pwd}/conf.json ${pwd}/api/conf/conf.json

exec ./manager-api