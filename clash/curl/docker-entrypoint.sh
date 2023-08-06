#!/usr/bin/env ash

configFilePath="/root/.config/clash/config.yaml"

echo $configFilePath

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

    # 提取数字部分到spaceNum
    # spaceNum=${key%%_*}
    spaceNum=$(echo $key | cut -d_ -f1)

    
    # 去除数字
    key="${key#${spaceNum}_}"
    
    # 小写
    # key="${key,,}"
    key=$(echo "$key" | tr 'A-Z' 'a-z')

    # 替换下划线为中杠
    key="${key//_/-}"

    sedRule="s%^\(\s\{$spaceNum\}\)[#;]*\(\s*\)$key\s*:.*%\1`echo $key`: `echo $val`%g"

    echo "sed -i -e $sedRule  $configFilePath";

    sed -i -e $sedRule  $configFilePath
  fi

done


cat $configFilePath

exec /clash



