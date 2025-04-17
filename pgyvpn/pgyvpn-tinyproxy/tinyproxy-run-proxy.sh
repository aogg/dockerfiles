#!/usr/bin/env bash


touch /var/log/tinyproxy/tinyproxy-proxy.log

IFS=',' read -ra proxies <<< "$TINYPROXY_PROXY"
i=0
for proxy in "${proxies[@]}"; do
((i++))

    if [ -n "$proxy" ];then
        cp /etc/tinyproxy/tinyproxy-proxy.conf /etc/tinyproxy/tinyproxy-proxy-${i}.conf
        sed -i -e "s%upstream http.*%upstream http ${proxy}%g" /etc/tinyproxy/tinyproxy-proxy-${i}.conf
        port=$(expr 8 - $i)
        echo "端口$port"
        sed -i -e "s%Port *%Port 888${port}%g" /etc/tinyproxy/tinyproxy-proxy-${i}.conf

        
(/usr/sbin/tinyproxy -c /etc/tinyproxy/tinyproxy-proxy-${i}.conf)
    fi
    # 这里可以添加针对每个代理地址的具体操作，比如使用 curl 测试连通性
    # curl --proxy "$proxy" http://example.com
done


(tail -f /var/log/tinyproxy/tinyproxy-proxy.log  | awk '{print "tinyproxy-proxy.log--文件输出: " $0}') &