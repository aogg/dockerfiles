#!/usr/bin/env ash



if [ ! -f "/root/.config/clash/config.yaml" ];then 
    # echo 'mixed-port: 7890' > /root/.config/clash/config.yaml
      cat > /root/.config/clash/config.yaml <<EOF
mixed-port: ${PORT:-7890}

# 设置为 true 以允许来自其他 LAN IP 地址的连接
allow-lan: true

# RESTful Web API 监听地址
external-controller: 0.0.0.0:${EXTERNAL_PORT:-9090}
EOF

fi

# 内容为空
if [ ! -s "/root/.config/clash/config.yaml" ];then 
    # echo 'mixed-port: 7890' > /root/.config/clash/config.yaml
      cat > /root/.config/clash/config.yaml <<EOF
mixed-port: ${PORT:-7890}

# 设置为 true 以允许来自其他 LAN IP 地址的连接
allow-lan: true


# RESTful Web API 监听地址
external-controller: 0.0.0.0:${EXTERNAL_PORT:-9090}
EOF

fi


exec /clash



