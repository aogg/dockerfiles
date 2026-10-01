# 与 Dockerfile 的区别：不下载官方 release 压缩包，改为克隆 GitHub 仓库后用 Go 源码编译
# 构建示例：docker build -f Dockerfile.go -t sniproxy:go .
# syntax=docker/dockerfile:1

# ================== 构建阶段：克隆仓库并用 Go 编译 ==================
FROM golang:alpine AS builder

# 目标平台架构（docker buildx 自动注入，如 amd64 / arm64）
ARG TARGETARCH=amd64
ARG TARGETVARIANT
# 仓库地址（国内服务器构建时可传加速地址，如：
# --build-arg GIT_URL=https://ghfast.top/https://github.com/XIU2/SNIProxy.git）
# --build-arg GIT_URL=https://ghfast.top/https://github.com/aogg/SNIProxy.git）
ARG GIT_URL=https://github.com/aogg/SNIProxy.git
# Go 模块代理（国内构建时可传 --build-arg GOPROXY=https://goproxy.cn,direct 加速）
ARG GOPROXY=https://proxy.golang.org,direct

# 安装 git 用于克隆仓库
RUN apk add --no-cache git

# 克隆仓库最新代码（浅克隆加速）
RUN git clone --depth 1 "${GIT_URL}" /tmp/src

WORKDIR /tmp/src

# 静态编译出无依赖的二进制（自动适配目标架构，arm/v7 时设置 GOARM）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    $( [ "${TARGETVARIANT}" = "v7" ] && echo "GOARM=7" ) \
    go build -trimpath -ldflags="-s -w" -o /tmp/sniproxy .

# ================== 运行阶段：与 Dockerfile 保持一致 ==================
# 运行镜像：使用轻量 alpine
FROM alpine

# 镜像信息
LABEL org.opencontainers.image.title="SNIProxy-aogg" \
      org.opencontainers.image.description="根据传入的域名(SNI)自动转发数据至该域名源服务器，常用于网站多服务器负载均衡" \
      org.opencontainers.image.source="https://github.com/aogg/SNIProxy"

# 安装基础依赖：bash 入口脚本、ca-certificates 根证书（HTTPS 下载用）、tzdata 时区数据
RUN apk add --no-cache bash ca-certificates tzdata

# 从构建阶段复制编译好的二进制并安装
COPY --from=builder /tmp/sniproxy /usr/local/bin/sniproxy
# 验证二进制可正常执行
RUN sniproxy -v

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
