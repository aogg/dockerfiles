#!/usr/bin/env bash 


NETMASK=${NETMASK:-255.255.255.0}
PORT=${PORT:-655}
ETH0_IP=${ETH0_IP:-0.0.0.0}

if [[ "${INVITE_URL}" ]];then
    # 客户端

    if [[ ! -f /etc/tinc/hosts/${NODE_NAME} ]];then
        tinc join $INVITE_URL
    fi



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


    echo '追加配置';
    echo -e $CONFIG_MORE
    echo -e $CONFIG_MORE >> /etc/tinc/hosts/${NODE_NAME}

else
    # 服务端
    NODE_IP=${NODE_IP:-10.5.5.1}

    tinc init tinc_server

    cat <<EOF > /etc/tinc/tinc-up
#!/bin/sh
ifconfig \$INTERFACE ${NODE_IP} netmask ${NETMASK}
EOF

    sed -i s/Port.*// /etc/tinc/hosts/tinc_server

    cat <<EOF >> /etc/tinc/hosts/tinc_server
Port=${PORT}
Subnet=${NODE_IP}/32
Address=${ETH0_IP}
EOF

    echo '追加配置';
    echo -e $CONFIG_MORE
    echo -e $CONFIG_MORE >> /etc/tinc/hosts/tinc_server


    echo 'Here is the INVITE_URL variable on the client side';
    echo '下面是客户端的INVITE_URL变量，5s后输出';
    echo 'tinc invite ${NODE_NAME}'
    if [[ -n "${NODE_NAME}" ]];then
        echo '开始5s后输出';
        (sleep 5 && echo $(echo '邀请链接为' && tinc invite ${NODE_NAME})) &
    fi


fi


# 不允许join -U nobody
exec tinc start -d $LOG_LEVEL -D



