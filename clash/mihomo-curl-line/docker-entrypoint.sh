#!/usr/bin/env ash

configFilePath="/root/.config/mihomo/config.yaml"

# 确保目录存在
mkdir -p /root/.config/mihomo/

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
    local servername=$(echo "$params" | sed -n 's/.*sni=\([^&]*\).*/\1/p')
    local path=$(echo "$params" | sed -n 's/.*path=\([^&]*\).*/\1/p' | sed 's|%2F|/|g')
    local host_header=$(echo "$params" | sed -n 's/.*host=\([^&]*\).*/\1/p')
    local flow=$(echo "$params" | sed -n 's/.*flow=\([^&]*\).*/\1/p')
    local fp=$(echo "$params" | sed -n 's/.*fp=\([^&]*\).*/\1/p')
    local tfo_val=$(echo "$params" | sed -n 's/.*tfo=\([^&]*\).*/\1/p')
    local alpn=$(echo "$params" | sed -n 's/.*alpn=\([^&]*\).*/\1/p' | sed 's|%2F|/|g')
    local public_key=$(echo "$params" | sed -n 's/.*pbk=\([^&]*\).*/\1/p')
    local short_id=$(echo "$params" | sed -n 's/.*sid=\([^&]*\).*/\1/p')
    local spider_x=$(echo "$params" | sed -n 's/.*spx=\([^&]*\).*/\1/p')

    [ -z "$name" ] && name="vless-${server}:${port}"
    [ -z "$servername" ] && servername="$server"

    local reality_opts=""
    if [ "$tls_val" = "reality" ]; then
        reality_opts="\"reality-opts\": {\"public-key\": \"$public_key\", \"short-id\": \"$short_id\"},"
    fi

    local alpn_opts=""
    [ -n "$alpn" ] && alpn_opts="\"alpn\": [\"h2\", \"http/1.1\"],"

    # 使用 yq 添加代理配置
    yq -i ".proxies += [{\"name\": \"$name\", \"type\": \"vless\", \"server\": \"$server\", \"port\": $port, \"uuid\": \"$uuid\", \"network\": \"${network:-tcp}\", \"tls\": $([ "$tls_val" = "tls" ] || [ "$tls_val" = "reality" ] && echo "true" || echo "false"), \"udp\": true, \"servername\": \"$servername\", \"flow\": \"$flow\", \"client-fingerprint\": \"$fp\", \"packet-encoding\": \"${spider_x:-xudp}\", $alpn_opts $reality_opts \"tcp-fast-open\": $([ "$tfo_val" = "1" ] && echo "true" || echo "false"), \"ws-opts\": {\"path\": \"$path\", \"headers\": {\"Host\": \"$host_header\"}}}]" "$configFilePath"
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

  # 5. 创建 load-balance 代理组并添加代理
  # 使用代码块 `{...}` 确保 while 循环和后续的 sed 命令在同一个 shell 中执行，
  # 这样 proxy_names 变量在循环结束后依然可用。
  echo "$vless_links" | {
    # 5.1 创建 load-balance 代理组
    echo "创建 'VLESS-LB' 负载均衡组..."
    yq -i '.proxy-groups += [{"name": "VLESS-LB", "type": "load-balance", "strategy": "round-robin", "url": "http://www.gstatic.com/generate_204", "interval": 300}]' "$configFilePath"

    while IFS= read -r line; do
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
    echo "proxy_names: $proxy_names"
    # 5.2 将所有代理添加到组中
    # 创建一个临时的 yml 文件来存储要合并的代理列表
    temp_proxies_file=$(mktemp)
    echo "proxy-groups:" > "$temp_proxies_file"
    echo "  - name: VLESS-LB" >> "$temp_proxies_file"
    echo "    url: 'http://www.gstatic.com/generate_204'" >> "$temp_proxies_file"
    echo "    interval: 300" >> "$temp_proxies_file"
    echo "    type: load-balance" >> "$temp_proxies_file"
    echo "    proxies:" >> "$temp_proxies_file"
    echo -e "$proxy_names" >> "$temp_proxies_file"
    # 使用 yq 合并代理列表到主配置文件
    yq eval-all '. as $item ireduce ({}; . * $item)' "$configFilePath" "$temp_proxies_file" > "${configFilePath}.tmp" && mv "${configFilePath}.tmp" "$configFilePath"
    rm "$temp_proxies_file"
  }

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
    echo "停止旧的 Mihomo 进程 (PID: $CLASH_PID)..."
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
  echo "启动 Mihomo 服务..."
  /mihomo &
  CLASH_PID=$!
  echo "Mihomo 已启动, 新 PID: $CLASH_PID"
  echo "========================================="
  
  # 首次启动后，在后台选择代理
if [ -f "/proxies-select.sh" ]; then
    (sleep 5 && /proxies-select.sh) &
fi

  # 等待 24 小时
  echo "配置完成，将在 24 小时后进行下一次更新。"
  sleep 86400
done
