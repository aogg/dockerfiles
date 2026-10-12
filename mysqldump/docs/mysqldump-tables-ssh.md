# adockero/mysqldump:tables-ssh

tables-ssh 家族基础版。通过 SSH 连到远端服务器，逐库逐表在远端执行 mysqldump 并计算 MD5，与上一次结果对比，只把有差异或新增的表经管道导入目标库。

## 构建信息

| 项 | 值 |
|---|---|
| 基础镜像 | `alpine` |
| 客户端 | `mysql-client`（MariaDB 版，含 mysqldump / mysql） |
| 其他软件 | bash、openssh-client、sshpass |
| 入口脚本 | `dump-import.md5.sh`（构建参数 `FILE_ARG`） |
| 入口 | `/bin/sh -c $ENTRYPOINT_RUN`，固定执行入口脚本，无需覆盖 entrypoint |

## 与同家族其他 tag 的差异

- [tables-ssh-cpu](./mysqldump-tables-ssh-cpu.md)：导出前检查远端 CPU 空闲率，低于阈值就等待
- [tables-ssh-pv](./mysqldump-tables-ssh-pv.md)：远端不落盘，容器内 `mysqldump | pv 限速 | mysql` 流水线，支持分页同步
- [tables-ssh-pv-mysql](./mysqldump-tables-ssh-pv-mysql.md)：同 tables-ssh-pv，客户端换成原版 MySQL

## 工作流程

1. sshpass + ssh 连接远端，验证连通
2. 远端逐表执行 `mysqldump | md5sum`，结果写到远端 `/tmp/dump-import-ssh-temp`
3. 与远端 `/tmp/dump-import-ssh`（上一次结果）做 diff，找出差异表和新增表
4. 容器内 mysqldump 导出差异表和新增表，管道导入 `IMPORT_DB_HOST`
5. 远端目录轮换，本次结果留作下次对比

远端 SSH 服务器必须存在：`mysql`、`mysqldump`、`md5sum`、`bash`，以及 `grep`、`awk`、`sed` 等基础命令。

`DB_HOST` 要同时能被远端服务器和本容器访问：远端用它算 MD5，容器用它导出差异表。

## 环境变量

### 数据库连接（从远端 SSH 服务器视角访问）

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_USER` | 数据库用户名，必填 | - |
| `DB_PASS` | 数据库密码，必填 | - |
| `DB_HOST` | 数据库主机，必填 | - |
| `DB_NAME` | 脚本读取但未使用 | - |

### 导入目标数据库

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `IMPORT_DB_USER` | 导入目标数据库用户名 | - |
| `IMPORT_DB_PASS` | 导入目标数据库密码 | - |
| `IMPORT_DB_HOST` | 导入目标数据库主机 | - |
| `IMPORT_ARGS` | 导入 mysql 的额外参数 | - |

### SSH 连接

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SSH_USER` | SSH 用户名 | - |
| `SSH_PASSWORD` | SSH 密码 | - |
| `SSH_IP` | SSH 服务器 IP | - |
| `SSH_ARGS` | SSH 额外参数，如 `-p 2222` | - |
| `STRICT_HOST_KEY_CHECKING` | 是否严格主机密钥检查 | no |

### 并发与过滤

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ASYNC_WAIT` | 设置后异步并发执行，结束时等待全部进程完成 | - |
| `ASYNC_WAIT_MAX` | 最大并发进程数 | 100 |
| `IGNORE_DATABASE` | 忽略的一个数据库名 | - |
| `IGNORE_DATABASE_TABLES` | 忽略的表，逗号分隔，支持 `库名.表名` 或 `表名` | - |
| `DUMP_ARGS` | mysqldump 额外参数 | - |

## 容器用法

```bash
docker run --rm \
  -e DB_HOST=db_host -e DB_PORT=3306 -e DB_USER=db_user -e DB_PASS=db_pass \
  -e SSH_IP=ssh_ip -e SSH_USER=ssh_user -e SSH_PASSWORD=ssh_pass \
  -e IMPORT_DB_HOST=import_host -e IMPORT_DB_USER=import_user -e IMPORT_DB_PASS=import_pass \
  -e IGNORE_DATABASE=test_db \
  -e IGNORE_DATABASE_TABLES=db1.log_table,tmp_table \
  -e ASYNC_WAIT=true -e ASYNC_WAIT_MAX=100 \
  adockero/mysqldump:tables-ssh
```

SSH 端口、密钥等参数放 `SSH_ARGS`，例如 `-e SSH_ARGS="-p 2222 -i /key"`。
