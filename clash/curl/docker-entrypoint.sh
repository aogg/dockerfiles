#!/usr/bin/env ash

# 根据别人的yaml，启动
configFilePath="/root/.config/clash/config.yaml"

# 确保目录存在
mkdir -p /root/.config/clash/

# 定义更新配置的函数
update_config() {
  echo "开始更新配置文件..."
  
  # 1. 下载配置文件
  if [ -n "${URL}" ]; then
    echo "从 ${URL} 下载配置文件..."
    wget -O /clash-config.yaml ${URL}
    if [ $? -ne 0 ]; then
      echo "错误：下载配置文件失败！"
      return 1
    fi
    cp /clash-config.yaml $configFilePath
  else
    echo "警告：未提供 URL 环境变量，跳过下载。"
    # 如果本地没有配置文件，则退出
    if [ ! -f "$configFilePath" ]; then
        echo "错误：未找到配置文件，并且未提供 URL。"
        return 1
    fi
  fi

  # 设置混合端口为7890
  yq -i '.mixed-port = 7890' $configFilePath

  # 2. 使用 yq 根据环境变量修改配置
  for env in $(printenv); do
    key=$(echo $env | cut -d= -f1)
    raw_val=$(echo $env | cut -d= -f2- | sed "s/^'\(.*\)'/\\1/g")

    if echo "$key" | grep -q "^CLASH_YQ_"; then
      echo "raw_val=$raw_val"
      # 在第一个=切分成 yq表达式路径 和 值
      yq_path="${raw_val%%=*}"
      yq_value="${raw_val#*=}"
      echo "  yq路径: $yq_path"
      echo "  设置值: $yq_value"

      echo "应用 yq 配置: $yq_path => $yq_value"
      if [ "$yq_value" = "null" ]; then
          # 值为null，删除该key
          echo "👉 值为null，执行删除: $yq_path"
          yq -i "del($yq_path)" "$configFilePath"
      elif [ "$yq_value" = "true" ] || [ "$yq_value" = "false" ]; then
        yq -i "$yq_path = $yq_value" "$configFilePath"
      else
          # 普通赋值，去掉你原来强制加\"$yq_value\"，避免bool/object被转字符串
          yq -i "$yq_path = \"$yq_value\"" "$configFilePath"
      fi      
      
      echo "✅ 应用完成 $yq_path = $yq_value"
      echo "应用 yq 配置完成: $key"
    fi
  done


  # 3. 检查并创建 'load' 代理组
  echo "检查 'load' 代理组..."
  load_group_exists=$(yq '.proxy-groups[] | select(.name == "load") | length' "$configFilePath")

  if [ -n "$load_group_exists" ] && [ "$load_group_exists" -gt 0 ]; then
      echo "'load' 代理组已存在，跳过创建。"
  else
      echo "创建 'load' 代理组..."

      # proxies_from_select_node=$(yq -o y '.proxies[].name' $configFilePath" | tr -d '\n')

      echo "从 '🔰 选择节点' 提取的代理: $proxies_from_select_node"
      yq -i '.proxy-groups += [{"name": "load", "type": "load-balance", "strategy": "round-robin", "url": "http://www.gstatic.com/generate_204", "interval": 300, "health-check": {"enable": true, "interval": 60, "url": "http://www.gstatic.com/generate_204", "timeout": 10}}]' "$configFilePath"

    # 直接在 yq 内部取所有节点名，避免 shell 拼接表达式
    yq -i '(.proxy-groups[] | select(.name == "load")).proxies = (.proxies | map(.name))' "$configFilePath"

      echo "将 'load' 添加到 GLOBAL 组..."
      global_index=$(yq '.proxy-groups | to_entries | .[] | select(.value.name == "GLOBAL") | .key' "$configFilePath")
      [ -n "$global_index" ] && yq -i ".proxy-groups[${global_index}].proxies = [\"load\"] + .proxy-groups[${global_index}].proxies" "$configFilePath"
  fi
  
  echo "配置文件处理完成。"
  return 0
}

# --- 主程序 ---

# 首次启动时更新配置
echo "首次启动，执行配置..."
update_config
if [ $? -ne 0 ]; then
    echo "首次配置失败，容器将退出。"
    exit 1
fi

# 首次启动后，在后台选择代理
if [ -f "/proxies-select.sh" ]; then
    (sleep 5 && /proxies-select.sh) &
fi

# 在后台启动 clash
echo "启动 Clash 服务..."
/clash &
CLASH_PID=$!

# 启动定时更新循环
echo "启动每日定时更新任务..."
while true; do
  # 等待 24 小时
  sleep 86400
  
  echo "========================================="
  echo "开始每日定时更新..."
  
  # 更新配置
  update_config
  
  # 重启 Clash
  echo "重启 Clash 服务以应用新配置..."
  kill $CLASH_PID
  /clash &

  # 首次启动后，在后台选择代理
  if [ -f "/proxies-select.sh" ]; then
      (sleep 5 && /proxies-select.sh) &
  fi

  CLASH_PID=$!
  echo "Clash 已重启, 新 PID: $CLASH_PID"
  echo "========================================="
done
