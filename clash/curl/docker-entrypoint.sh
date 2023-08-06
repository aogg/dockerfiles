#!/usr/bin/env ash

configFilePath="/root/.config/clash/config.yaml"
if [ ! -f "/clash-config.yaml" ];then 
  wget -O /clash-config.yaml ${URL}
  cp /clash-config.yaml $configFilePath
fi

# 读取所有环境变量
for env in $(printenv); do

  # 分割变量
  key=$(echo $env | cut -d= -f1)
  val=$(echo $env | cut -d= -f2)

  # echo "$key => $val"

  # 判断key变量是否存在ClASH_这个前置
  if echo "$key" | grep -q "^CLASH_"; then
    # 去掉CLASH_前缀
    key="${key#CLASH_}"
    
    # 小写
    # key="${key,,}"
    key=$(echo "$key" | tr 'A-Z' 'a-z')

    # 替换下划线为中杠
    key="${key//_/-}"

    sed -i -e "s%\(\s*\)[#;]*\(\s*\)$key\s*:.*%\1\2`echo $key`:`echo $val`%g" $configFilePath
  fi

done



exec /clash



