# CoreDNS Docker 镜像

基于 [coredns/coredns](https://github.com/coredns/coredns) 构建的 Docker 镜像，支持通过 `HOST_URL_*` 环境变量定时下载远程 hosts 文件，与内置 hosts 合并后自动生效，用于广告拦截、域名劫持等场景。

## adockero/coredns:hosts 镜像标签

- `adockero/coredns:hosts` - 支持定时下载远程 hosts 文件的 CoreDNS

### 特性

- 通过 `HOST_URL_*` 环境变量声明多个远程 hosts 源，自动循环下载
- `HOST_FETCH_INTERVAL` 控制下载循环间隔
- 单个源下载失败只记录日志，不影响其他源和 DNS 服务，下轮自动重试
- 下载文件先写临时文件再原子替换，避免 coredns reload 读到半截文件
- Corefile 配置 `reload 5s`，hosts 文件更新后自动生效，无需重启

### 快速开始

#### 基本使用

```bash
docker run -d --name coredns \
  -p 53:53/udp -p 53:53/tcp \
  adockero/coredns:hosts
```

不设置 `HOST_URL_*` 时行为同普通 CoreDNS，直接使用镜像内置 hosts 文件。

#### 拉取远程 hosts 列表

```bash
docker run -d --name coredns \
  -p 53:53/udp -p 53:53/tcp \
  -e HOST_URL_ADBLOCK=https://adaway.org/hosts.txt \
  -e HOST_URL_SCAM=https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
  -e HOST_FETCH_INTERVAL=600 \
  adockero/coredns:hosts
```

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `HOST_URL_<NAME>` | 远程 hosts 文件地址，`<NAME>` 为文件名（自动转小写），可设置多个 | - |
| `HOST_FETCH_INTERVAL` | 循环下载间隔（秒） | 300 |
| `HOST_FALLBACK_FORWARD` | 未匹配 hosts 时是否回退到上游 forward。设为 `false`/`0`/`no`/`off` 时移除 `forward`，未命中的查询直接返回 SERVFAIL | true |

#### 变量命名与文件对应关系

```
HOST_URL_ADBLOCK=https://adaway.org/hosts.txt   ->  /data/hosts.d/adblock
HOST_URL_SCAM=https://xxx/hosts                 ->  /data/hosts.d/scam
```

### 工作原理

1. 启动时备份镜像内置 hosts 为 `/data/hosts.base`，作为合并基底
2. 后台循环按 `HOST_FETCH_INTERVAL` 间隔下载所有 `HOST_URL_*` 到 `/data/hosts.d/`
3. 合并 `hosts.base` + `hosts.d/` 下所有文件写入 `/data/hosts`（coredns hosts 插件只能读单个文件）
4. coredns 通过 `reload 5s` 自动加载更新后的 hosts
5. 单个下载失败时跳过该源，保留旧文件，循环继续

### 默认 Corefile

挂载 `/etc/coredns/` 可替换为自定义 Corefile：

```
.:53 {
    errors
    debug

    hosts /data/hosts {
        reload 5s
        ttl 30
        fallthrough
    }

    forward . 223.5.5.5
    log
}
```

设置 `HOST_FALLBACK_FORWARD=false` 时，启动脚本会自动移除 Corefile 中的 `forward` 行，
hosts 未命中的查询不再转发上游，直接返回 SERVFAIL（适合纯拦截/纯内网解析场景）：

### 数据持久化

挂载 `/data/` 后，下载的 hosts 文件与合并结果会持久化，容器重建后不重新下载也能直接使用：

```bash
docker run -d --name coredns \
  -p 53:53/udp \
  -v /opt/coredns/data:/data \
  -e HOST_URL_ADBLOCK=https://adaway.org/hosts.txt \
  adockero/coredns:hosts
```

### Docker Compose 示例

```yaml
version: '3'
services:
  coredns:
    image: adockero/coredns:hosts
    container_name: coredns
    ports:
      - "53:53/udp"
      - "53:53/tcp"
    volumes:
      - ./data:/data
    environment:
      - HOST_URL_ADBLOCK=https://adaway.org/hosts.txt
      - HOST_URL_SCAM=https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
      - HOST_FETCH_INTERVAL=600
    restart: unless-stopped
```

### 验证

```bash
# 查询内置 hosts 中存在的域名
dig @127.0.0.1 ads.example.com

# 查看下载与合并日志
docker logs -f coredns
```

## 相关链接

- [CoreDNS 官方文档](https://coredns.io/)
- [CoreDNS GitHub](https://github.com/coredns/coredns)
- [hosts 插件文档](https://coredns.io/plugins/hosts/)
