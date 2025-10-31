#!/usr/bin/env ash

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

  # 2. 使用 yq 根据环境变量修改配置
  for env in $(printenv); do
    key=$(echo $env | cut -d= -f1)
    val=$(echo $env | cut -d= -f2- | sed "s/^'\(.*\)'/\\1/g")

    if echo "$key" | grep -q "^CLASH_YQ_"; then
      echo "应用 yq 配置: $key => $val"
      yq -i "$val" $configFilePath
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
      proxies_from_select_node=$(yq -o json '.proxy-groups[] | select(.name == "🔰 选择节点") | .proxies' "$configFilePath" | tr -d '\n')

      if [ -z "$proxies_from_select_node" ] || [ "$proxies_from_select_node" = "null" ]; then
        echo "警告：未在 '🔰 选择节点' 组中找到任何代理，无法创建 'load' 组。"
      else
        echo "从 '🔰 选择节点' 提取的代理: $proxies_from_select_node"
        yq -i '.proxy-groups += [{"name": "load", "type": "load-balance", "strategy": "round-robin", "url": "http://www.gstatic.com/generate_204", "interval": 300, "health-check": {"enable": true, "interval": 60, "url": "http://www.gstatic.com/generate_204", "timeout": 10}}]' "$configFilePath"
        yq -i '(.proxy-groups[] | select(.name == "load")).proxies = '"$proxies_from_select_node" "$configFilePath"

        echo "将 'load' 添加到 GLOBAL 组..."
        global_index=$(yq '.proxy-groups | to_entries | .[] | select(.value.name == "GLOBAL") | .key' "$configFilePath")
        [ -n "$global_index" ] && yq -i ".proxy-groups[${global_index}].proxies = [\"load\"] + .proxy-groups[${global_index}].proxies" "$configFilePath"
      fi
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
