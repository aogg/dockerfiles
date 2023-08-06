#!/usr/bin/env ash

configFilePath="/root/.config/clash/profiles/config.yaml"

mkdir -p /root/.config/clash/profiles;

echo $configFilePath

if [ ! -f "/clash-config.yaml" ];then 
  wget -O /clash-config.yaml ${PROFILE_URL}
  cp /clash-config.yaml $configFilePath
fi

# 读取所有环境变量
for env in $(printenv); do

  # 分割变量
  key=$(echo $env | cut -d= -f1)
  val=$(echo $env | cut -d= -f2-)

  # echo "$key => $val"

  # 判断key变量是否存在CLASH_YQ_这个前置
  if echo "$key" | grep -q "^CLASH_YQ_"; then

    yq -i "$val" $configFilePath

    # 去掉CLASH_前缀
    # key="${key#CLASH_YQ_}"

    # # 提取数字部分到spaceNum
    # # spaceNum=${key%%_*}
    # spaceNum=$(echo $key | cut -d_ -f1)

    
    # # 去除数字
    # key="${key#${spaceNum}_}"
    
    # # 小写
    # # key="${key,,}"
    # key=$(echo "$key" | tr 'A-Z' 'a-z')

    # # 替换下划线为中杠
    # key="${key//_/-}"

    # echo '替换已启用的';
    # sedRule="s%^\(\s\{$spaceNum\}\)$key\s*:.*%\1`echo $key`: `echo $val`%g"

    # echo "sed -i -e $sedRule  $configFilePath";

    # sed -i -e "$sedRule"  $configFilePath
    
    # echo '替换被注释的';
    # sedRule="s%^\(\s\{$spaceNum\}\)[#;]\s*$key\s*:.*%\1`echo $key`: `echo $val`%g"
    
    # echo "sed -i -e $sedRule  $configFilePath";

    # sed -i -e "$sedRule"  $configFilePath
  fi

done


cat $configFilePath

# exec /clash

exec /docker-entrypoint.sh

