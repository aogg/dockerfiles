#!/usr/bin/env ash

configFilePath="/root/.config/clash/config.yaml"
curlHost=$(yq ".external-controller" $configFilePath)




curl --location --request PUT 'http://'"${curlHost}"'/proxies/GLOBAL' \
--header 'Accept: application/json, text/plain, */*' \
--header 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
--header 'Connection: keep-alive' \
--header 'Content-Type: application/json' \
--data '{"name":"'"${PROXIE_NAME}"'"}'

#   --header 'Origin: http://clash.razord.top' \
#   --header 'Referer: http://clash.razord.top/' \
#   --header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.67' \

# BusyBox v1.36.1
# wget --no-check-certificate \
#   --method 'PUT' \
#   --timeout=0 \
#   --header 'Accept: application/json, text/plain, */*' \
#   --header 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
#   --header 'Connection: keep-alive' \
#   --header 'Content-Type: application/json' \
#   --post-data '{"name":"'"${PROXIE_NAME}"'"}' \
#    'http://'"${curlHost}"'/proxies/GLOBAL'

