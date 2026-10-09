# mihomo-curl

基于 [mihomo](https://github.com/MetaCubeX/mihomo) (Clash.Meta) 的订阅自动拉取镜像:
启动时(以及每天)用 `curl` 下载订阅 yaml, 经 `yq` 处理后启动 mihomo。

特性:

- URL 模板支持日期占位符 `[Y]` `[m]` `[d]` 与自增占位符 `[int]`
- 单实例模式: URL 不含 `[int]` 时, 下载一个配置, 在 `PORT` (默认 7890) 启动
- 多实例模式: URL 含 `[int]` 时, `[int]` 从 0 自增, 每个配置启动一个实例
  (端口 7891, 7892, ... 逐一递增), 另有一个固定端口 7890 的聚合实例,
  将所有实例作为上游做负载均衡, 对外提供统一入口
- 每个实例启动前先用 `mihomo -t` 测试配置 (会触发 geo 数据库下载,
  网络失败自动重试最多 3 次), 测试与启动在实例间并发执行
- 每日自动更新配置, 下载或测试失败时保留旧实例继续运行
- 每行 mihomo 日志带 `[进程端口: xxxx]` 标签, 多实例日志不混淆
- github 相关 URL 自动加代理前缀, 方便国内网络拉取

## 构建

Dockerfile 的 `COPY` 引用了 `mihomo-curl/` 和 `common/` 两个目录,
构建上下文必须是本目录的上一级 (`clash/`):

```sh
cd d:/code/www/my/github/dockerfiles/clash
docker build -t mihomo-curl -f mihomo-curl/Dockerfile .
```

## docker run

### 单实例模式

URL 不含 `[int]` 占位符, 下载单个配置, 在 7890 端口启动:

```sh
docker run -d --name mihomo \
  -p 7890:7890 \
  -e URL="https://example.com/config.yaml" \
  mihomo-curl
```

### 多实例模式

URL 含 `[int]` 占位符时启用。每个成功下载的配置启动一个实例,
代理端口从 7891 起自增, API 端口从 9091 起自增; 7890/9090 固定给聚合实例:

```sh
docker run -d --name mihomo \
  -p 7890:7890 -p 9090:9090 \
  -p 7891-7895:7891-7895 \
  -p 9091-9095:9091-9095 \
  -e URL="https://clashnode.github.io/uploads/[Y]/[m]/[int]-[Y][m][d].yaml" \
  -e START_DATE=2026-09-28 \
  mihomo-curl
```

上例中, 端口段 `7891-7895` 最多允许 5 个实例 (0-4), 按数据实际存在数量启动;
客户端统一连 7890 (聚合负载均衡), 也可直连单个实例端口。

### 常用操作

```sh
# 查看日志 (每行带 [进程端口: xxxx] 标签区分实例)
docker logs -f mihomo

# 使用代理
curl -x http://127.0.0.1:7890 https://www.google.com

# 聚合实例 API (切换代理组等)
curl http://127.0.0.1:9090/proxies
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `URL` | (必填) | 订阅地址模板, 占位符见下 |
| `PORT` | `7890` | 单实例/聚合实例的代理端口 |
| `CTRL_PORT_BASE` | `9090` | API (external-controller) 基准端口, 实例从 +1 自增 |
| `START_DATE` | (空) | 日期回溯最早日期 (`YYYY-MM-DD`), 不设置仅用今天 |
| `GITHUB_PROXY` | `https://hk.gh-proxy.org/` | github 相关 URL 的代理前缀, 置空禁用 |
| `GEOX_URL_PREFIX` | `https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release` | 配置缺少 geox-url 时写入的默认 geo 数据 URL 前缀 |
| `PROXIE_NAME` | `load` | 启动后自动选择的代理组名 (proxies-select.sh 用) |
| `CONFIG_YQ_*` | (无) | 任意 `CONFIG_YQ_` 前缀的环境变量, 值为 `yq路径=值`, 用 yq 改写配置; 值为 `null` 时删除该字段 |

### URL 占位符

| 占位符 | 含义 | 示例 |
|--------|------|------|
| `[Y]` | 4 位年份 | `2026` |
| `[m]` | 2 位月份 | `09` |
| `[d]` | 2 位日期 | `29` |
| `[int]` | 自增整数, 从 0 开始 | `0`, `1`, `2`, ... |

日期回溯规则: 设置 `START_DATE` 后, 第 0 个 `[int]` 按 今天 -> START_DATE
倒序逐日尝试下载, 命中即锁定该天; 后续 `[int]` 只在锁定的日期上自增。

### 环境变量示例

```sh
docker run -d --name mihomo \
  -p 7890:7890 \
  -e URL="https://example.com/config.yaml" \
  -e GITHUB_PROXY="" \
  -e GEOX_URL_PREFIX="https://gh-proxy.com/https://github.com/MetaCubeX/meta-rules-dat@release" \
  -e CONFIG_YQ_LOG_LEVEL="log-level=debug" \
  mihomo-curl
```

## 行为细节

- 实例端口计算: 实例 `i` 的代理端口为 `PORT+1+i`, API 端口为 `CTRL_PORT_BASE+1+i`
- 启动前 `mihomo -t` 测试配置 (触发 geo 数据库下载), 失败自动重试最多 3 次;
  3 次均失败则跳过启动 (已有旧实例时旧实例继续运行)
- 订阅下载 curl 重试 3 次, 3 次全部失败则停止 `[int]` 自增
- 每隔 24 小时自动重新拉取订阅并重启实例, 失败时保留旧配置/旧进程
- mihomo 日志格式为 `time=... level=... msg=...`, 加上本脚本的前缀后形如:
  `[进程端口: 7891] time="..." level=info msg="[TCP] ..."`
