#!/usr/bin/env ash

# configFilePath="/root/.config/clash/profiles/config.yaml"
configFilePath="/root/.config/clash/config.yaml"

# mkdir -p /root/.config/clash/profiles;

echo $configFilePath
first_bool=0

if [ ! -f "/clash-config.yaml" ];then 
  wget -O /clash-config.yaml ${URL}
  cp /clash-config.yaml $configFilePath
  first_bool=1
fi

# 读取所有环境变量
for env in $(printenv); do

  # 分割变量
  key=$(echo $env | cut -d= -f1)
  val=$(echo $env | cut -d= -f2- | sed "s/^'\(.*\)'/\\1/g")


  # 判断key变量是否存在CLASH_YQ_这个前置
  if echo "$key" | grep -q "^CLASH_YQ_"; then

    echo "开始配置   $key => $val"
    yq -i "$val" $configFilePath
    echo "开始配置--结束   $key => $val"

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



echo "2. 检查 'load' 代理组是否已存在（去重）"
# 检查是否已有名为 'load' 的代理组
load_group_exists=$(yq '.proxy-groups[] | select(.name == "load") | length' "$configFilePath")

if [ -n "$load_group_exists" ] && [ "$load_group_exists" -gt 0 ]; then
    echo "'load' 代理组已存在，跳过创建"
else
    echo "创建 'load' 代理组"

echo "创建 load-balance 组并引用 '🔰 选择节点' 的代理"
# 从 '🔰 选择节点' 组中提取代理列表
proxies_from_select_node=$(yq -o json '.proxy-groups[] | select(.name == "🔰 选择节点") | .proxies' "$configFilePath" | tr -d '\n')

echo "提取的代理列表：$proxies_from_select_node"


  # 创建一个新的 load-balance 代理组，并使用上面提取的代理
  yq -i '.proxy-groups += [{"name": "load", "type": "load-balance", "strategy": "round-robin", "url": "http://www.gstatic.com/generate_204", "interval": 300, "health-check": {"enable": true, "interval": 60, "url": "http://www.gstatic.com/generate_204", "timeout": 10}}]' "$configFilePath"
  yq -i '(.proxy-groups[] | select(.name == "load")).proxies = '"$proxies_from_select_node" "$configFilePath"

  echo "将 GLOBAL 组的代理设置为 'load'"
  # 查找 GLOBAL 组的索引
  global_index=$(yq '.proxy-groups | to_entries | .[] | select(.value.name == "GLOBAL") | .key' "$configFilePath")

  # 如果找到了 GLOBAL 组，则更新其 proxies 列表
  [ -n "$global_index" ] && yq -i ".proxy-groups[${global_index}].proxies = [\"load\"] + .proxy-groups[${global_index}].proxies" "$configFilePath"
fi

# cat $configFilePath

if [ "$first_bool" -eq 1 ];then 
    ((sleep 2 && /proxies-select.sh) &)
fi

exec /clash

# exec /docker-entrypoint.sh
