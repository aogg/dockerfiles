# adockero/mysqldump:tables-5.7

tables 家族唯一对外推送的 tag。逐库逐表导出、导入和直连管道迁移，不经过 SSH，数据库地址由容器直接访问。基于 `mysql:5.7-debian` 构建，客户端来自基础镜像。

## 构建信息

| 项 | 值 |
|---|---|
| 基础镜像 | `mysql:5.7-debian`（构建参数 `BASE_FROM`） |
| 构建目录 | `./mysqldump/tables` |
| Dockerfile | `mysqldump/tables/Dockerfile` |
| 入口 | `/dump.sh` |
| 其他脚本 | `/import.sh`、`/dump-import.sh`（需覆盖 entrypoint 调用） |

### 关于同名重复构建

workflow 里有一个 step 名叫「构建镜像 adockero/mysqldump:tables」（`BASE_FROM=mysql:debian`），但它推的 tag 同样是 `tables-5.7`；随后「构建镜像 adockero/mysqldump:tables-5.7」step（`BASE_FROM=mysql:5.7-debian`）会再构建并推送一次。最终 `tables-5.7` tag 指向 `mysql:5.7-debian` 那次构建。不存在独立的 `tables:latest` 镜像。

## 与其他家族的差异

- 基础版 [mysqldump:8/5.7/latest](./mysqldump-8.md)：按库导出单个 sql；本镜像按表导出
- tables-ssh 家族（[tables-ssh](./mysqldump-tables-ssh.md) 等）：经 SSH 在远端操作；本镜像直连数据库

## 内含脚本

| 脚本 | 用途 | 调用方式 |
|------|------|----------|
| `/dump.sh` | 逐表导出到 `/mysqldump/$db/$table.sql` | 默认入口 |
| `/import.sh` | 导入 `/mysqldump/$db/*.sql` | `--entrypoint /import.sh` |
| `/dump-import.sh` | 逐表 `mysqldump \| mysql` 直连管道迁移，不落盘 | `--entrypoint /dump-import.sh` |

## 环境变量

### 数据库连接

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_HOST` | 数据库主机，必填 | - |
| `DB_USER` | 数据库用户名，必填 | - |
| `DB_PASS` | 数据库密码，必填 | - |
| `DB_NAME` | 脚本读取但未使用 | - |

### 并发与过滤（三个脚本共用）

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ASYNC_WAIT` | 设置后异步并发执行，结束时等待全部进程完成 | - |
| `ASYNC_WAIT_MAX` | 最大并发进程数 | 100 |
| `IGNORE_DATABASE` | 忽略的一个数据库名 | - |
| `IGNORE_DATABASE_TABLES` | 忽略的表，逗号分隔，支持 `库名.表名` 或 `表名` | - |

### dump-import.sh 额外变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ONLY_DATABASE` | 只同步列出的库，逗号分隔 | - |
| `IMPORT_DATABASE_SUFFIX` | 导入时库名追加的后缀，如 `_bak` | - |
| `IMPORT_DB_USER` | 导入目标数据库用户名 | - |
| `IMPORT_DB_PASS` | 导入目标数据库密码 | - |
| `IMPORT_DB_HOST` | 导入目标数据库主机 | - |
| `IMPORT_ARGS` | 导入 mysql 的额外参数 | - |
| `DUMP_ARGS` | mysqldump 额外参数 | - |

## 容器用法

### 逐表导出

```bash
docker run --rm -v $PWD:/mysqldump -e DB_HOST=db_host -e DB_USER=db_user -e DB_PASS=db_pass \
-e ASYNC_WAIT=true -e IGNORE_DATABASE_TABLES=db1.log_table \
adockero/mysqldump:tables-5.7 --skip-lock-tables
```

镜像名后的参数原样传给 mysqldump，输出到 `/mysqldump/$db/$table.sql`。

### 逐表导入

```bash
docker run --rm -v $PWD:/mysqldump -e DB_HOST=local_host -e DB_USER=db_user -e DB_PASS=db_pass \
-e ASYNC_WAIT=true \
--entrypoint /import.sh \
adockero/mysqldump:tables-5.7
```

按 `/mysqldump/$db/*.sql` 的目录结构逐表导入，镜像名后的参数原样传给 mysql。

### 直连管道迁移（不落盘）

```bash
docker run --rm \
  -e DB_HOST=src_host -e DB_USER=db_user -e DB_PASS=db_pass \
  -e IMPORT_DB_HOST=dst_host -e IMPORT_DB_USER=import_user -e IMPORT_DB_PASS=import_pass \
  -e ONLY_DATABASE=db1,db2 -e IMPORT_DATABASE_SUFFIX=_bak \
  -e ASYNC_WAIT=true -e ASYNC_WAIT_MAX=100 \
  --entrypoint /dump-import.sh \
  adockero/mysqldump:tables-5.7
```

逐表 `mysqldump | mysql` 直连迁移；`IMPORT_DATABASE_SUFFIX` 非空时导入到 `库名+后缀` 的库。
