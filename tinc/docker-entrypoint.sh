#!/usr/bin/env bash 


NETMASK=${NETMASK:-255.255.255.0}
PORT=${PORT:-655}
ETH0_IP=${ETH0_IP:-0.0.0.0}

if [[ "${INVITE_URL}" ]];then
    # 客户端

    tinc join $INVITE_URL



    # 配置地址
    cat <<EOF > /etc/tinc/tinc-up
#!/bin/sh
ifconfig \$INTERFACE ${NODE_IP} netmask ${NETMASK}
EOF

    # Port 0 表示随机选择 - 不使用固定端口避免被检测
    cat <<EOF >> /etc/tinc/hosts/${NODE_NAME}
Port=${PORT}
Subnet=${NODE_IP}/32
EOF

else
    # 服务端
    NODE_IP=${NODE_IP:-10.0.0.1}

    tinc init tinc_server

    cat <<EOF > /etc/tinc/tinc-up
#!/bin/sh
ifconfig \$INTERFACE ${NODE_IP} netmask ${NETMASK}
EOF

    cat <<EOF >> /etc/tinc/hosts/tinc_server
Port=${PORT}
Subnet=${NODE_IP}/32
Address=${ETH0_IP}
EOF


    echo 'Here is the INVITE_URL variable on the client side';
    echo '下面是客户端的INVITE_URL变量';
    echo 'tinc invite ${NODE_NAME}'
    if [[ -z "${NODE_NAME}" ]];then
        tinc invite ${NODE_NAME}
    fi


fi


exec tinc start -d 2 -D -U nobody



