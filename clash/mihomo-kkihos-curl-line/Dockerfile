FROM golang:alpine AS builder

WORKDIR /src
# 安装构建依赖并编译，由于要求分层构建且尽量小，开启 CGO_ENABLED=0 以及 -trimpath -ldflags '-s -w'
RUN apk add --no-cache git \
    && git clone -b alpha-xhttp-clone https://github.com/Amarxisoc/kkihos.git . \
    && go mod download \
    && CGO_ENABLED=0 go build -tags with_gvisor -trimpath -ldflags '-s -w -buildid=' -o mihomo

# 最终极简镜像
FROM alpine:latest

# 结合原版 mihomo-curl-line 的依赖需要 
RUN apk add --no-cache ca-certificates tzdata yq curl perl

# 环境变量
ENV PORT=7890
ENV EXTERNAL_PORT=9090
ENV PROXIE_NAME="自动选择"

EXPOSE 7890 9090

# 拷贝编译出的由于需要复用共用脚本，产物直接保持 /mihomo 的名称
COPY --from=builder /src/mihomo /mihomo

# 引用共用的启动脚本和测速脚本
COPY mihomo-curl-line/docker-entrypoint.sh /docker-entrypoint.sh
COPY common/proxies-select.sh /proxies-select.sh

RUN chmod +x /mihomo /docker-entrypoint.sh /proxies-select.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
