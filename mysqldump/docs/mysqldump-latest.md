# adockero/mysqldump（latest）

基础版 mysqldump 导出镜像的 latest tag，基于 `mysql:debian` 构建，`mysqldump` / `mysql` 客户端来自基础镜像。修正自 camil/mysqldump，完整支持把参数传给 mysqldump。

## 构建信息

| 项 | 值 |
|---|---|
| 基础镜像 | `mysql:debian`（构建参数 `BASE_FROM`） |
| 构建目录 | `./mysqldump` |
| Dockerfile | `mysqldump/Dockerfile` |
| 入口 | `/dump.sh` |
| 导入脚本 | `/import.sh`（需覆盖 entrypoint 调用） |

## 与同家族其他 tag 的差异

- [mysqldump:8](./mysqldump-8.md)：基础镜像为 `mysql:8-debian`
- [mysqldump:5.7](./mysqldump-5.7.md)：基础镜像为 `mysql:5.7-debian`

三个 tag 共用同一 Dockerfile 和脚本。latest 跟随官方 `mysql:debian` 标签，不锁定 MySQL 版本，基础镜像更新时版本随之变化；需要固定版本用 `:8` 或 `:5.7`。

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_HOST` | 数据库主机，必填 | - |
| `DB_PORT` | 数据库端口 | 3306 |
| `DB_USER` | 数据库用户名，必填 | - |
| `DB_PASS` | 数据库密码，必填 | - |
| `DB_NAME` | 数据库名；`ALL_DATABASES` 为空时必填 | - |
| `ALL_DATABASES` | 设置后操作所有数据库，跳过 `information_schema`、`performance_schema`、`mysql` 和 `_` 开头的库 | - |
| `IGNORE_DATABASE` | 额外忽略的一个数据库名 | - |
| `ASYNC_WAIT` | 设置后异步并发执行，结束时等待全部进程完成 | - |

兼容 `MYSQL_ENV_DB_USER` 等旧式变量名作为缺省值。

## 容器用法

导出结果写到容器内 `/mysqldump`，用 `-v $PWD:/mysqldump` 挂到当前目录。

### 导出单个数据库

```bash
docker run --rm -v $PWD:/mysqldump -e DB_HOST=db_host -e DB_PORT=3306 -e DB_USER=db_user -e DB_PASS=db_pass -e DB_NAME=db_name \
adockero/mysqldump --skip-lock-tables --add-drop-table --extended-insert
```

镜像名后的参数原样传给 mysqldump，输出文件为 `/mysqldump/db_name.sql`。

### 导出所有数据库（异步并发）

```bash
docker run --rm -v $PWD:/mysqldump -e DB_HOST=db_host -e DB_USER=db_user -e DB_PASS=db_pass \
-e ALL_DATABASES=true -e ASYNC_WAIT=true -e IGNORE_DATABASE=test_db \
adockero/mysqldump
```

每个库输出 `/mysqldump/$db.sql`，dump 语句带 `--databases`。

### 导入

```bash
# 单库：读取 /mysqldump/db_name.sql
docker run --rm -v $PWD:/mysqldump -e DB_HOST=local_host -e DB_USER=db_user -e DB_PASS=db_pass -e DB_NAME=db_name \
--entrypoint /import.sh \
adockero/mysqldump

# 全库：导入 /mysqldump 下所有 .sql 文件
docker run --rm -v $PWD:/mysqldump -e DB_HOST=local_host -e DB_USER=db_user -e DB_PASS=db_pass \
-e ALL_DATABASES=true -e ASYNC_WAIT=true \
--entrypoint /import.sh \
adockero/mysqldump
```

镜像名后的参数原样传给 mysql。
