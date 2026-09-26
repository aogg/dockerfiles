#!/usr/bin/env ash

configFilePath="/root/.config/clash/config.yaml"

# 确保目录存在
mkdir -p /root/.config/clash/

# 生成基础配置文件
generate_base_config() {
    cat > "$configFilePath" <<EOF
mixed-port: ${PORT:-7890}
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:${EXTERNAL_PORT:-9090}
proxies: []
proxy-groups:
  - name: GLOBAL
    type: select
    proxies:
      - VLESS-LB
      - DIRECT
rules:
  - MATCH,GLOBAL
EOF
}

# 解析 vless 链接并添加到配置
parse_vless() {
    local line="$1"
    # vless://uuid@host:port?params#name
    local name=$(echo "$line" | awk -F'#' '{print $2}' | sed 's/%/ /g' | xargs)
    local uuid=$(echo "$line" | awk -F'[@:]' '{print $2}')
    local server=$(echo "$line" | awk -F'[@:]' '{print $3}')
    local port=$(echo "$line" | awk -F'[:?]' '{print $3}')
    
    # 提取所有查询参数
    local params=$(echo "$line" | awk -F'?' '{print $2}' | awk -F'#' '{print $1}')
    local network=$(echo "$params" | sed -n 's/.*type=\([^&]*\).*/\1/p')
    local tls_val=$(echo "$params" | sed -n 's/.*security=\([^&]*\).*/\1/p')
    local sni=$(echo "$params" | sed -n 's/.*sni=\([^&]*\).*/\1/p')
    local path=$(echo "$params" | sed -n 's/.*path=\([^&]*\).*/\1/p' | sed 's|%2F|/|g')
    local host_header=$(echo "$params" | sed -n 's/.*host=\([^&]*\).*/\1/p')
    local flow=$(echo "$params" | sed -n 's/.*flow=\([^&]*\).*/\1/p')
    local fp=$(echo "$params" | sed -n 's/.*fp=\([^&]*\).*/\1/p')
    local tfo_val=$(echo "$params" | sed -n 's/.*tfo=\([^&]*\).*/\1/p')

    [ -z "$name" ] && name="vless-${server}:${port}"

    # 使用 yq 添加代理配置
    yq -i ".proxies += [{\"name\": \"$name\", \"type\": \"vless\", \"server\": \"$server\", \"port\": $port, \"uuid\": \"$uuid\", \"network\": \"$network\", \"tls\": $([ "$tls_val" = "tls" ] && echo "true" || echo "false"), \"udp\": true, \"servername\": \"$sni\", \"flow\": \"$flow\", \"client-fingerprint\": \"$fp\", \"tcp-fast-open\": $([ "$tfo_val" = "1" ] && echo "true" || echo "false"), \"ws-opts\": {\"path\": \"$path\", \"headers\": {\"Host\": \"$host_header\"}}}]" "$configFilePath"
    echo "$name"
}

# 解析 vmess 链接并添加到配置
parse_vmess() {
    local line="$1"
    # vmess://<base64>
    local b64_data=$(echo "$line" | sed 's/vmess:\/\///')
    local json_data=$(echo "$b64_data" | base64 -d)

    local name=$(echo "$json_data" | yq -r '.ps')
    local server=$(echo "$json_data" | yq -r '.add')
    local port=$(echo "$json_data" | yq -r '.port')
    local uuid=$(echo "$json_data" | yq -r '.id')
    local alterId=$(echo "$json_data" | yq -r '.aid')
    local network=$(echo "$json_data" | yq -r '.net')
    local tls_val=$(echo "$json_data" | yq -r '.tls')
    local path=$(echo "$json_data" | yq -r '.path')
    local host_header=$(echo "$json_data" | yq -r '.host')

    [ -z "$name" ] && name="vmess-${server}:${port}"

    yq -i ".proxies += [{\"name\": \"$name\", \"type\": \"vmess\", \"server\": \"$server\", \"port\": $port, \"uuid\": \"$uuid\", \"alterId\": $alterId, \"cipher\": \"auto\", \"network\": \"$network\", \"tls\": $([ "$tls_val" = "tls" ] && echo "true" || echo "false"), \"udp\": true, \"ws-opts\": {\"path\": \"$path\", \"headers\": {\"Host\": \"$host_header\"}}}]" "$configFilePath"
    echo "$name"
}

# 解析 trojan 链接并添加到配置
parse_trojan() {
    local line="$1"
    # trojan://password@host:port#name
    local name=$(echo "$line" | awk -F'#' '{print $2}' | sed 's/%/ /g' | xargs)
    local password=$(echo "$line" | awk -F'[@:]' '{print $2}')
    local server=$(echo "$line" | awk -F'[@:]' '{print $3}')
    local port=$(echo "$line" | awk -F'[:?]' '{print $3}')
    local sni=$(echo "$line" | sed -n 's/.*sni=\([^&]*\).*/\1/p')

    [ -z "$sni" ] && sni="$server"
    [ -z "$name" ] && name="trojan-${server}:${port}"

    yq -i ".proxies += [{\"name\": \"$name\", \"type\": \"trojan\", \"server\": \"$server\", \"port\": $port, \"password\": \"$password\", \"sni\": \"$sni\", \"udp\": true}]" "$configFilePath"
    echo "$name"
}

# 解析 ss 链接并添加到配置
parse_ss() {
    local line="$1"
    # ss://<base64>#name
    local name=$(echo "$line" | awk -F'#' '{print $2}' | sed 's/%/ /g' | xargs)
    local b64_part=$(echo "$line" | sed -e 's/ss:\/\///' -e 's/#.*//')
    local decoded_part=$(echo "$b64_part" | base64 -d)
    local cipher=$(echo "$decoded_part" | awk -F: '{print $1}')
    local password=$(echo "$decoded_part" | awk -F: '{print $2}' | awk -F@ '{print $1}')
    local server=$(echo "$decoded_part" | awk -F@ '{print $2}' | awk -F: '{print $1}')
    local port=$(echo "$decoded_part" | awk -F@ '{print $2}' | awk -F: '{print $2}')

    [ -z "$name" ] && name="ss-${server}:${port}"

    yq -i ".proxies += [{\"name\": \"$name\", \"type\": \"ss\", \"server\": \"$server\", \"port\": $port, \"cipher\": \"$cipher\", \"password\": \"$password\", \"udp\": true}]" "$configFilePath"
    echo "$name"
}

# 定义更新配置的函数
update_config() {
  echo "开始更新配置文件..."
  
  # 1. 检查 URL
  if [ -z "${URL}" ]; then
    echo "错误：未提供 URL 环境变量！"
    return 1
  fi

  # 2. 下载并解码 vless 链接
  echo "从 ${URL} 下载并解析 vless 链接..."
  vless_links=$(curl -sL "${URL}" | base64 -d)
  if [ $? -ne 0 ] || [ -z "$vless_links" ]; then
    echo "错误：下载或解码 vless 链接失败！"
    return 1
  fi

  # 3. 生成基础配置
  generate_base_config

  # 4. 解析 vless 链接并生成 proxies
  echo "生成代理配置..."
  proxy_names=""
  
  # 使用 while read 逐行处理，防止 for 循环因空格分割问题出错
  echo "$vless_links" | while IFS= read -r line; do
    # 跳过空行
    if [ -z "$line" ]; then
      continue
    fi

    local name=""
    # 根据协议头选择解析函数
    if echo "$line" | grep -q "^vless://"; then
      name=$(parse_vless "$line")
    elif echo "$line" | grep -q "^vmess://"; then
      name=$(parse_vmess "$line")
    elif echo "$line" | grep -q "^trojan://"; then
      name=$(parse_trojan "$line")
    elif echo "$line" | grep -q "^ss://"; then
      name=$(parse_ss "$line")
    else
      echo "跳过不支持的链接类型: $line"
      continue
    fi

    # 拼接代理名称列表
    if [ -n "$name" ]; then
        proxy_names="$proxy_names\n      - \"$name\""
    fi
  done

  # 5. 创建 load-balance 代理组
  echo "创建 'VLESS-LB' 负载均衡组..."
  yq -i '.proxy-groups += [{"name": "VLESS-LB", "type": "load-balance", "strategy": "round-robin", "url": "http://www.gstatic.com/generate_204", "interval": 300}]' "$configFilePath"
  
  # 将所有代理添加到组中
  # yq 不支持直接从变量插入多行 yaml，所以我们用 sed
  sed -i "/- name: VLESS-LB/a \    proxies:$(echo -e "$proxy_names")" "$configFilePath"

  echo "配置文件处理完成。"
  return 0
}

# --- 主程序 ---

# 启动定时更新循环
while true; do
  echo "========================================="
  echo "开始执行配置更新..."
  
  # 杀死旧的 Clash 进程（如果存在）
  if [ -n "$CLASH_PID" ]; then
    echo "停止旧的 Clash 进程 (PID: $CLASH_PID)..."
    kill $CLASH_PID
    # 等待进程完全退出
    wait $CLASH_PID 2>/dev/null
  fi
  
  # 更新配置
  update_config
  if [ $? -ne 0 ]; then
    echo "配置更新失败，将在 1 小时后重试..."
    sleep 3600
    continue
  fi
  
  # 启动新的 Clash 进程
  echo "启动 Clash 服务..."
  /clash &
  CLASH_PID=$!
  echo "Clash 已启动, 新 PID: $CLASH_PID"
  echo "========================================="
  
  # 首次启动后，在后台选择代理
if [ -f "/proxies-select.sh" ]; then
    (sleep 5 && /proxies-select.sh) &
fi

  # 等待 24 小时
  echo "配置完成，将在 24 小时后进行下一次更新。"
  sleep 86400
done
