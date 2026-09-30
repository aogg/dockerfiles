# 运行镜像：使用轻量 alpine
FROM alpine

# 镜像信息
LABEL org.opencontainers.image.title="SNIProxy" \
      org.opencontainers.image.description="根据传入的域名(SNI)自动转发数据至该域名源服务器，常用于网站多服务器负载均衡" \
      org.opencontainers.image.source="https://github.com/XIU2/SNIProxy"

# 目标平台架构（docker buildx 自动注入，如 amd64 / arm64），用于下载对应架构的 release 包
ARG TARGETARCH=amd64

# 安装基础依赖：bash 入口脚本、ca-certificates 根证书（HTTPS 下载用）、tzdata 时区数据
RUN apk add --no-cache bash ca-certificates tzdata

# 下载官方 release 二进制压缩包（始终下载最新版）并安装
# 国内服务器构建时可改用镜像加速地址，如：
# https://ghfast.top/https://github.com/XIU2/SNIProxy/releases/latest/download/sniproxy_linux_amd64.tar.gz
ADD https://github.com/XIU2/SNIProxy/releases/latest/download/sniproxy_linux_${TARGETARCH}.tar.gz /tmp/src.tar.gz
RUN mkdir -p /tmp/pkg \
    && tar -zxf /tmp/src.tar.gz -C /tmp/pkg \
    # 从解压结果中找到 sniproxy 二进制并安装（兼容压缩包内有无顶层目录两种情况）
    && install -m 755 "$(find /tmp/pkg -type f -name sniproxy | head -n 1)" /usr/local/bin/sniproxy \
    && rm -rf /tmp/pkg /tmp/src.tar.gz \
    # 验证二进制可正常执行
    && sniproxy -v

# 拷贝默认配置文件
COPY config.yaml /etc/sniproxy/config.yaml

# 拷贝入口脚本（run 时根据 -e 环境变量自动改写配置，如开启 socks5 前置代理）
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 配置文件目录（运行时挂载卷可覆盖默认配置）
VOLUME ["/etc/sniproxy/"]

# HTTPS(SNI 转发)端口 和 HTTP(重定向到 HTTPS)端口
EXPOSE 443 80

# 入口脚本：处理环境变量后启动 sniproxy
ENTRYPOINT ["docker-entrypoint.sh"]

# 默认启动参数：指定配置文件（-d 可开启调试模式）
CMD ["-c", "/etc/sniproxy/config.yaml"]
