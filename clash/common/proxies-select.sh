#!/usr/bin/env ash

defaultConfigFilePath="/root/.config/clash/config.yaml"

# 如果 $1 不为空，则 newConfigPath=$1，否则 newConfigPath=$configFilePath
configFilePath="${1:-$defaultConfigFilePath}"
curlHost=$(yq ".external-controller" $configFilePath)

echo "选择代理节点: ${PROXIE_NAME}"
echo curl --location --request PUT 'http://'"${curlHost}"'/proxies/GLOBAL' \
--header 'Accept: application/json, text/plain, */*' \
--header 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
--header 'Connection: keep-alive' \
--header 'Content-Type: application/json' \
--data '{"name":"'"${PROXIE_NAME}"'"}'

# 实例可能尚未启动完成(API 端口未监听)或进程已退出,
# curl 失败(HTTP 状态 000/非 2xx)时等待重试, 最多 15 次 * 2 秒 = 30 秒
try=1
maxTry=15
while [ "$try" -le "$maxTry" ]; do
  httpCode=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 10 \
    --location --request PUT 'http://'"${curlHost}"'/proxies/GLOBAL' \
    --header 'Accept: application/json, text/plain, */*' \
    --header 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    --header 'Connection: keep-alive' \
    --header 'Content-Type: application/json' \
    --data '{"name":"'"${PROXIE_NAME}"'"}' 2>/dev/null)

  case "$httpCode" in
    2*)
      echo "✅ 选择完成: ${curlHost} -> ${PROXIE_NAME} (HTTP ${httpCode})"
      exit 0
      ;;
  esac
  echo "警告: API ${curlHost} 未就绪或请求失败 (HTTP ${httpCode}), 第 ${try}/${maxTry} 次, 2 秒后重试"
  try=$((try + 1))
  sleep 2
done

echo "错误: 重试 ${maxTry} 次后仍无法连接 API ${curlHost}, 放弃为该实例选择节点"
exit 0

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

