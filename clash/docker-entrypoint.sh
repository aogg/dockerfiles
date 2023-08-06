#!/usr/bin/env ash



if [ ! -f "/root/.config/clash/config.yaml" ];then 
    # echo 'mixed-port: 7890' > /root/.config/clash/config.yaml
      cat > /root/.config/clash/config.yaml <<EOF
mixed-port: ${PORT:-8090}

# 设置为 true 以允许来自其他 LAN IP 地址的连接
# allow-lan: true
EOF

fi

# 内容为空
if [ ! "$(cat '/root/.config/clash/config.yaml')" ];then 
    # echo 'mixed-port: 7890' > /root/.config/clash/config.yaml
      cat > /root/.config/clash/config.yaml <<EOF
mixed-port: ${PORT:-8090}

# 设置为 true 以允许来自其他 LAN IP 地址的连接
# allow-lan: true
EOF

fi


exec /clash



