# GOST Docker 镜像

基于 [gogost/gost](https://github.com/go-gost/gost) 构建的 Docker 镜像，支持通过环境变量动态配置。

## adockero/gost:http-auth 镜像标签

- `adockero/gost:http-auth` - 带 HTTP 基础认证的 HTTP 代理

### 快速开始

#### 基本使用

```bash
docker run -d --name gost \
  -p 8080:8080 \
  adockero/gost:http-auth
```

代理地址：`http://admin:admin@your-ip:8080`

#### 自定义用户名密码

通过环境变量修改配置：

```bash
docker run -d --name gost \
  -p 8080:8080 \
  -e ENV_YAML_authers_0_auths_0_username=myuser \
  -e ENV_YAML_authers_0_auths_0_password=mypass \
  adockero/gost:http-auth
```

代理地址：`http://myuser:mypass@your-ip:8080`

### 环境变量配置

镜像支持通过 `ENV_YAML_` 前缀的环境变量动态修改 YAML 配置。

#### 语法规则

```
ENV_YAML_<path>=<value>
```

- `path`：YAML 配置路径，用下划线 `_` 代替点 `.`，数组索引直接用数字表示
- `value`：配置值

#### 配置示例

| 环境变量 | 对应 YAML 路径 |
|---------|---------------|
| `ENV_YAML_services_0_addr` | `services[0].addr` |
| `ENV_YAML_authers_0_auths_0_username` | `authers[0].auths[0].username` |
| `ENV_YAML_authers_0_auths_0_password` | `authers[0].auths[0].password` |

#### 修改监听端口

```bash
docker run -d --name gost \
  -p 3128:3128 \
  -e ENV_YAML_services_0_addr=":3128" \
  adockero/gost:http-auth
```

#### 添加多个认证用户

```bash
docker run -d --name gost \
  -p 8080:8080 \
  -e ENV_YAML_authers_0_auths_0_username=admin \
  -e ENV_YAML_authers_0_auths_0_password=admin123 \
  -e ENV_YAML_authers_0_auths_1_username=user2 \
  -e ENV_YAML_authers_0_auths_1_password=pass2 \
  adockero/gost:http-auth
```

### 默认配置

```yaml
services:
- name: service-0
  addr: ":8080"
  handler:
    type: http
    auther: auther-0
  listener:
    type: tcp
authers:
- name: auther-0
  auths:
  - username: admin
    password: admin
```

### Docker Compose 示例

```yaml
version: '3'
services:
  gost:
    image: adockero/gost:http-auth
    container_name: gost
    ports:
      - "8080:8080"
    environment:
      - ENV_YAML_authers_0_auths_0_username=${GOST_USER:-admin}
      - ENV_YAML_authers_0_auths_0_password=${GOST_PASS:-admin}
    restart: unless-stopped
```

## 相关链接

- [GOST 官方文档](https://gost.run/)
- [GOST GitHub](https://github.com/go-gost/gost)
