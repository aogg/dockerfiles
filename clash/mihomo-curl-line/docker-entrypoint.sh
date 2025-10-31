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
    local configFilePath="$2"  # 接收配置文件路径参数（需从调用处传入）
    local debugBool="$3"  # 接收配置文件路径参数（需从调用处传入）

    # 提取 # 后的名称（解码 URL 编码，如 %20 转空格）
    local name=$(echo "$line" | awk -F'#' '{if (NF>=2) print $2; else print ""}')
    # 解码名称中的 URL 编码（处理空格、特殊字符）
    name=$(echo "$name" | sed -e 's/%20/ /g' -e 's/%23/#/g' -e 's/%2F/\//g' | xargs)

    # 提取 UUID、服务器、端口（基础信息）
    local uuid=$(echo "$line" | awk -F'vless://|@' '{print $2}')  # 从 vless:// 后、@ 前提取 UUID
    # local server_port=$(echo "$line" | awk -F'@' '{print $2}' | awk -F'\?' '{print $1}')  # 提取 @ 后、? 前的 server:port
    # local server=$(echo "$server_port" | awk -F':' '{print $1}')
    # local port=$(echo "$server_port" | awk -F':' '{print $2}')
    # 提取 @ 后面的部分（服务器+端口+参数），再剥离参数部分（? 及后面内容）
    local server_port_str=$(echo "$line" | sed -E 's/^vless:\/\/[^@]+@([^?]+).*$/\1/')

    # 从 server_port_str 中拆分 server 和 port（处理无端口的情况，默认443）
    local server=$(echo "$server_port_str" | sed -E 's/^([^:]+)(:.*)?$/\1/')  # 提取 : 之前的部分作为服务器
    local port=$(echo "$server_port_str" | sed -E 's/^[^:]+:([0-9]+)$/\1/')   # 提取 : 之后的数字作为端口

    # 若未提取到端口，默认使用 443
    if [ -z "$port" ] || ! echo "$port" | grep -q '^[0-9]\+$'; then
        port=443
    fi


    # 若未指定端口，默认 443
    [ -z "$port" ] && port=443

    # 若名称为空，用 server:port 生成
    [ -z "$name" ] && name="vless-${server}:${port}"

    # 提取查询参数（? 后的部分，排除 # 及后面内容）
    local params=$(echo "$line" | awk -F'\?' '{if (NF>=2) print $2; else print ""}' | awk -F'#' '{print $1}')

    # 解析各参数（默认值合理设置）
    #  type
    local extracted_network=$(echo "$params" | sed -n 's/.*type=\([^&]*\).*/\1/p')
    local network=${extracted_network:-tcp}
    
    local encryption=$(echo "$params" | sed -n 's/.*encryption=\([^&]*\).*/\1/p')
    local host_header=$(echo "$params" | sed -n 's/.*host=\([^&]*\).*/\1/p')
    # 从完整链接中提取 path，并进行 URL 解码
    # 1. 提取 path=... 部分，直到 & 或 # 或行尾
    # 2. 去掉 path= 前缀
    # 3. URL 解码（处理 %2F, %3D, %3F 等）
    local path=$(echo "$line" | sed -n 's/.*[?&]path=\([^&#]*\).*/\1/p' | perl -pe 's/%(..)/chr(hex($1))/eg')
    
    # 构建 WebSocket 配置（仅当 network=ws 时）
    local ws_opts=""
    if [ "$network" = "ws" ]; then
        # 处理 path 和 host_header（为空则不填）
        local ws_path=$( [ -n "$path" ] && echo "\"path\": \"$path\"," || echo "" )
        local ws_host=$( [ -n "$host_header" ] && echo "\"Host\": \"$host_header\"" || echo "" )
        ws_opts="\"ws-opts\": {${ws_path} \"headers\": {$ws_host}},"
    fi


    local tls_val=$(echo "$line" | sed -n 's/.*security=\([^&]*\).*/\1/p')
    # 提取 sni，如果不存在则使用 server 作为默认值
    local extracted_sni=$(echo "$line" | sed -n 's/.*[?&]sni=\([^&#]*\).*/\1/p')
    local servername=${extracted_sni:-$server}
    local flow=$(echo "$line" | sed -n 's/.*flow=\([^&]*\).*/\1/p')
    local fp=$(echo "$line" | sed -n 's/.*fp=\([^&]*\).*/\1/p' || echo "")
    local tfo_val=$(echo "$line" | sed -n 's/.*tfo=\([^&]*\).*/\1/p')
    local alpn=$(echo "$line" | sed -n 's/.*alpn=\([^&]*\).*/\1/p' | sed 's/%2C/,/g')  # 解码逗号
    local public_key=$(echo "$line" | sed -n 's/.*pbk=\([^&]*\).*/\1/p')
    local short_id=$(echo "$line" | sed -n 's/.*sid=\([^&]*\).*/\1/p')
    local spider_x=$(echo "$line" | sed -n 's/.*spx=\([^&]*\).*/\1/p')

    # 构建 reality 配置（仅当 security=reality 时）
    local reality_opts=""
    if [ "$tls_val" = "reality" ] && [ -n "$public_key" ]; then
        reality_opts="\"reality-opts\": {\"public-key\": \"$public_key\", \"short-id\": \"$short_id\"},"
    fi

    # 构建 ALPN 配置（若有值）
    local alpn_opts=""
    if [ -n "$alpn" ]; then
        # 将 alpn 参数按逗号拆分并转为数组（如 h2,http/1.1 → ["h2", "http/1.1"]）
        alpn_arr=$(echo "$alpn" | sed 's/,/","/g')
        alpn_opts="\"alpn\": [\"$alpn_arr\"],"
    fi


    # 构建 TLS 开关（security=tls 或 reality 时启用）
    local tls_enabled=$([ "$tls_val" = "tls" ] || [ "$tls_val" = "reality" ] && echo "true" || echo "false")

    # 构建 TCP 快速打开（tfo=1 时启用）
    local tfo_enabled=$([ "$tfo_val" = "1" ] && echo "true" || echo "false")

    # 构建 packet-encoding（默认 xudp，无则空）
    local packet_encoding=${spider_x:-xudp}
    [ -z "$packet_encoding" ] && packet_encoding=""


    # 根据echo作为返回的
    if [ "$debugBool" = "true" ]; then
      echo "最后结果---------------------------------"
      echo "params: $params"
      echo "name: $name"
      echo "server: $server"
      echo "port: $port"
      echo "uuid: $uuid"
      echo "network: $network"
      echo "encryption: $encryption"
      echo "host-header: $host_header"
      echo "path: $path"
      echo "tls: $tls_enabled"
      echo "servername: $servername"
      echo "flow: $flow"
      echo "fp: $fp"
      echo "packet-encoding: $packet_encoding"
      echo "alpn: $alpn"
      echo "public-key: $public_key"
      echo "short-id: $short_id"
      echo "spider-x: $spider_x"
      echo "tfo: $tfo_enabled"
      echo "reality-opts: $reality_opts"
      echo "ws-opts: $ws_opts"
      echo "alpn-opts: $alpn_opts"
      echo "最后结果----------proxies-----------------------"

      echo ".proxies += [{
          \"name\": \"$name\",
          \"type\": \"vless\",
          \"server\": \"$server\",
          \"port\": $port,
          \"uuid\": \"$uuid\",
          \"network\": \"$network\",
          \"tls\": $tls_enabled,
          \"udp\": true,
          \"servername\": \"$servername\",
          \"flow\": \"$flow\",
          \"client-fingerprint\": \"$fp\",
          \"packet-encoding\": \"$packet_encoding\",
          $alpn_opts
          $reality_opts
          $ws_opts
          \"tcp-fast-open\": $tfo_enabled
      }]"
      echo "最后结果---------------------------------"
      return
    fi

    # 使用 yq 插入代理配置（格式严格对齐 YAML 规范）
    yq -i ".proxies += [{
        \"name\": \"$name\",
        \"type\": \"vless\",
        \"server\": \"$server\",
        \"port\": $port,
        \"uuid\": \"$uuid\",
        \"network\": \"$network\",
        \"tls\": $tls_enabled,
        \"udp\": true,
        \"servername\": \"$servername\",
        \"flow\": \"$flow\",
        \"client-fingerprint\": \"$fp\",
        \"packet-encoding\": \"$packet_encoding\",
        $alpn_opts
        $reality_opts
        $ws_opts
        \"tcp-fast-open\": $tfo_enabled
    }]" "$configFilePath"

    echo "$name"  # 返回生成的节点名称
}

# 解析 vmess 链接并添加到配置
parse_vmess() {
    local line="$1"
    local configFilePath="$2"
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
    local configFilePath="$2"
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
    local configFilePath="$2"
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

        # 示例输入数据（可以是一个文件或管道）
        input_data=$(echo "$line" | perl -pe 's/\+/ /g; s/%(..)/chr(hex($1))/eg')

        echo "处理链接: $input_data"

        local name=""
        # 根据协议头选择解析函数
        if echo "$input_data" | grep -q "^vless://"; then
          name=$(parse_vless "$input_data" "$configFilePath")

          echo "调试信息"
          parse_vless "$input_data" "$configFilePath" "true"
        elif echo "$input_data" | grep -q "^vmess://"; then
          name=$(parse_vmess "$input_data" "$configFilePath")
        elif echo "$input_data" | grep -q "^trojan://"; then
          name=$(parse_trojan "$input_data" "$configFilePath")
        elif echo "$input_data" | grep -q "^ss://"; then
          name=$(parse_ss "$input_data" "$configFilePath")
        else
          echo "跳过不支持的链接类型: $input_data"
          echo "跳过不支持的链接类型line: $line"
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
    echo "开始替换"
    yq eval-all '. as $item ireduce ({}; . * $item)' "$configFilePath" "$temp_proxies_file" > "${configFilePath}.tmp"
    if [ $? -ne 0 ]; then
      echo "错误：合并代理组失败！"
      return 1
    else
      mv "${configFilePath}.tmp" "$configFilePath"  
      rm "$temp_proxies_file"
    fi

    # 最后检查下VLESS-LB
    echo "最后检查下VLESS-LB"
    yq eval '.proxy-groups[] | select(.name == "VLESS-LB")' "$configFilePath"
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
