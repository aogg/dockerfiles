# SNIProxy

[XIU2/SNIProxy](https://github.com/XIU2/SNIProxy) 的 docker 镜像，根据传入的域名(SNI)自动转发数据至该域名源服务器，常用于网站多服务器负载均衡、基于域名(SNI)的端口转发等。

- 镜像：`adockero/sniproxy`
- `alpine` 运行，构建时下载官方 release 最新版二进制（支持 amd64/arm64 等多架构）
- 入口脚本 `docker-entrypoint.sh`：run 时通过 `-e` 环境变量自动改写配置（如开启 socks5 前置代理），无需改配置文件

## 目录说明

- `Dockerfile`：镜像构建文件
- `config.yaml`：默认配置文件（打进镜像 `/etc/sniproxy/config.yaml`，可挂载覆盖）
- `docker-entrypoint.sh`：入口脚本（根据环境变量生成运行时配置后启动）

## 快速使用

```bash
# 直接运行（使用镜像内置默认配置：监听 443/80，允许所有域名）
docker run -d --name sniproxy --restart=always -p 443:443 -p 80:80 adockero/sniproxy

# 挂载自定义配置文件
docker run -d --name sniproxy --restart=always \
    -p 443:443 -p 80:80 \
    -v /your/path/config.yaml:/etc/sniproxy/config.yaml \
    adockero/sniproxy

# 调试模式（追加 -d 参数）
docker run --rm -p 443:443 -v /your/path/config.yaml:/etc/sniproxy/config.yaml adockero/sniproxy -d
```

> 注意：容器内监听 `:443`（所有 IPv4+IPv6），映射宿主机端口即可。
> 如果只需本机使用，可将映射改为 `-p 127.0.0.1:443:443`。

## 环境变量（-e）

| 变量 | 说明 | 默认值 |
| ---- | ---- | ---- |
| `SOCKS5_ADDR` | socks5 前置代理地址 `ip:port`，设置后自动开启（如 `-e SOCKS5_ADDR=172.17.0.1:40000`） | 未设置（不开启） |
| `SOCKS5_HOST` | socks5 代理 IP（和 `SOCKS5_PORT` 配合使用，`SOCKS5_ADDR` 优先） | - |
| `SOCKS5_PORT` | socks5 代理端口（和 `SOCKS5_HOST` 配合使用） | - |
| `SOCKS5_USERNAME` | socks5 代理账号（可选） | - |
| `SOCKS5_PASSWORD` | socks5 代理密码（可选） | - |
| `SNIPROXY_CONFIG` | 基础配置文件路径 | `/etc/sniproxy/config.yaml` |

开启 socks5 前置代理示例：

```bash
# 方式一：-e 直接指定 ip:port
docker run -d --name sniproxy --restart=always \
    -p 443:443 -p 80:80 \
    -e SOCKS5_ADDR=172.17.0.1:40000 \
    adockero/sniproxy

# 方式二：分开指定 ip 和 端口 + 账号密码
docker run -d --name sniproxy --restart=always \
    -p 443:443 -p 80:80 \
    -e SOCKS5_HOST=172.17.0.1 \
    -e SOCKS5_PORT=40000 \
    -e SOCKS5_USERNAME=admin \
    -e SOCKS5_PASSWORD=abc123 \
    adockero/sniproxy
```

原理：入口脚本检测到相关环境变量后，把基础配置文件复制为运行时副本（`/tmp/sniproxy-runtime.yaml`），
在副本中移除旧的 socks5 配置行并追加新的（`enable_socks5: true`、`socks_addr` 等），
再用副本启动 —— 不会改动挂载进来的原配置文件。
流量走向：`访客 <=> SNIProxy <=> Socks5 <=> 目标网站`（比如套一层 WARP）。

## 配置文件说明

默认配置（见 [config.yaml](config.yaml)）：

```yaml
listen_addr: ":443"        # 监听端口（SNI 转发）
listen_addr_http: ":80"    # 可选：HTTP 重定向为 HTTPS

allow_all_hosts: true      # 二选一：允许所有域名

# rules:                   # 二选一：仅允许指定域名（及其所有子域名）
#   - example.com
```

更多配置项（Socks5 前置代理等）见 [官方 README](https://github.com/XIU2/SNIProxy#%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6%E8%AF%B4%E6%98%8E-configyaml)。

## 端口

| 端口 | 说明 |
| ---- | ---- |
| 443 | HTTPS（解析 SNI 域名并转发至源站） |
| 80  | HTTP（重定向为 HTTPS，可不映射） |

## 工作流程示意

```
访问 example.com <=> SNIProxy(解析 SNI 获得目标域名 <=> DNS 解析获得源站 IP) <=> 源站(example.com)
```

## 相关

- 源码：<https://github.com/XIU2/SNIProxy>
- 构建 workflow：[.github/workflows/sniproxy.yml](../.github/workflows/sniproxy.yml)
