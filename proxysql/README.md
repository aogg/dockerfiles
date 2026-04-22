# ProxySQL Docker

基于 [proxysql/proxysql](https://hub.docker.com/r/proxysql/proxysql) 官方镜像，支持通过环境变量配置。

## 端口

| 端口 | 用途 |
|------|------|
| 6032 | Admin 管理接口 |
| 6033 | MySQL 协议代理端口 |
| 6070 | Stats Web 接口 |

## 环境变量

### PROXY_ 前缀 — 配置被代理的 MySQL 基础信息

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `PROXY_MYSQL_HOST` | `mysql` | 后端 MySQL 地址 |
| `PROXY_MYSQL_PORT` | `3306` | 后端 MySQL 端口 |
| `PROXY_MYSQL_USERNAME` | `root` | 客户端连接用户 |
| `PROXY_MYSQL_PASSWORD` | `root` | 客户端连接密码 |
| `PROXY_MONITOR_USERNAME` | `monitor` | 健康检查用户 |
| `PROXY_MONITOR_PASSWORD` | `monitor` | 健康检查密码 |
| `PROXY_WRITER_HOSTGROUP` | `1` | 写组 hostgroup ID |
| `PROXY_SERVER_VERSION` | `5.5.30` | 对外显示的 MySQL 版本 |

### ENV_ 前缀 — 通用配置覆盖

格式 `ENV_{section}__{key}` 或 `ENV_{key}`（默认 mysql_variables section）：

```
ENV_mysql_variables__threads=8
ENV_threads=4
```

仅首次启动（cnf 文件不存在时）生效，后续重启保留已有配置。

## 日志

- 查询日志写入 `/var/log/proxysql/proxysql_events.log`
- 每天午夜自动轮转为 `proxysql_events_2026-04-21.log`
- 7 天前的日志自动 gzip 压缩
- 挂载 `/var/log/proxysql` 持久化日志

## 使用示例

```bash
docker run -d \
  -p 6032:6032 -p 6033:6033 -p 6070:6070 \
  -e PROXY_MYSQL_HOST=10.0.0.100 \
  -e PROXY_MYSQL_PORT=3306 \
  -e PROXY_MYSQL_USERNAME=appuser \
  -e PROXY_MYSQL_PASSWORD=secret123 \
  -e PROXY_MONITOR_USERNAME=monitor \
  -e PROXY_MONITOR_PASSWORD=monitor123 \
  -v proxysql-data:/var/lib/proxysql \
  -v proxysql-log:/var/log/proxysql \
  adockero/proxysql
```

### 连接 ProxySQL

```bash
# Admin 管理
mysql -h127.0.0.1 -P6032 -uadmin -padmin

# 通过代理连接 MySQL
mysql -h127.0.0.1 -P6033 -uroot -proot
```

## 动态配置

通过 Admin 接口可动态添加后端服务器、读写分离规则等：

```sql
-- 添加读服务器
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight)
VALUES (2, 'mysql-slave', 3306, 1);

-- 读写分离：SELECT 走读组
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply)
VALUES (1, 1, '^SELECT', 2, 1);

LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```
