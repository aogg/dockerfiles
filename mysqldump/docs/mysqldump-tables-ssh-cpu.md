# adockero/mysqldump:tables-ssh-cpu

tables-ssh 家族的 CPU 保护版。逻辑与 [tables-ssh](./mysqldump-tables-ssh.md) 相同：SSH 连远端，逐库逐表在远端 mysqldump 并计算 MD5，与上一次结果对比，只把有差异或新增的表经管道导入目标库。区别是导出前先看远端 CPU 空闲率，低于阈值就等待，不给远端加压。

## 构建信息

| 项 | 值 |
|---|---|
| 基础镜像 | `alpine` |
| 客户端 | `mysql-client`（MariaDB 版，含 mysqldump / mysql） |
| 其他软件 | bash、openssh-client、sshpass |
| 入口脚本 | `dump-import.md5.cpu.sh`（构建参数 `FILE_ARG`） |
| 入口 | `/bin/sh -c $ENTRYPOINT_RUN`，固定执行入口脚本，无需覆盖 entrypoint |

## 与同家族其他 tag 的差异

与 [tables-ssh](./mysqldump-tables-ssh.md) 相比：

- 启动远端 `mpstat` 监控进程，把 CPU 空闲率实时写到容器内 `/tmp/get_remote_cpu_idle`，监控进程挂掉会自动重启
- 每张表发起导出前检查：并发数低于 `ASYNC_WAIT_MAX` 且远端 CPU 空闲率大于 `CPU_IDLE_MIN` 才继续，否则等待
- 每张表导出之间间隔 `DUMP_WAIT_SECONDS` 秒
- 远端 SSH 服务器额外必须有 `mpstat`（来自 sysstat 包）
- 不使用 pv

其余差异见 [tables-ssh-pv](./mysqldump-tables-ssh-pv.md) 和 [tables-ssh-pv-mysql](./mysqldump-tables-ssh-pv-mysql.md)。

## 工作流程

1. sshpass + ssh 连接远端，验证连通
2. 启动远端 mpstat 监控，实时记录 CPU 空闲率
3. 远端逐表执行 `mysqldump | md5sum`，结果写到远端 `/tmp/dump-import-ssh-temp`
4. 与远端 `/tmp/dump-import-ssh`（上一次结果）做 diff，找出差异表和新增表
5. 容器内 mysqldump 导出差异表和新增表，管道导入 `IMPORT_DB_HOST`
6. 远端目录轮换，本次结果留作下次对比

远端 SSH 服务器必须存在：`mysql`、`mysqldump`、`md5sum`、`mpstat`（sysstat 包）、`bash`，以及 `grep`、`awk`、`sed` 等基础命令。

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
| `CPU_IDLE_MIN` | 远端 CPU 空闲率最低百分比（%），低于此值不发起新导出 | 15 |
| `ASYNC_WAIT` | 设置后异步并发执行，结束时等待全部进程完成 | - |
| `ASYNC_WAIT_MAX` | 最大并发进程数 | 100 |
| `DUMP_WAIT_SECONDS` | 每张表导出之间的间隔秒数 | 0.6 |
| `IGNORE_DATABASE` | 忽略的一个数据库名 | - |
| `IGNORE_DATABASE_TABLES` | 忽略的表，逗号分隔，支持 `库名.表名` 或 `表名` | - |
| `DUMP_ARGS` | mysqldump 额外参数 | - |

## 容器用法

```bash
docker run --rm \
  -e DB_HOST=db_host -e DB_PORT=3306 -e DB_USER=db_user -e DB_PASS=db_pass \
  -e SSH_IP=ssh_ip -e SSH_USER=ssh_user -e SSH_PASSWORD=ssh_pass \
  -e IMPORT_DB_HOST=import_host -e IMPORT_DB_USER=import_user -e IMPORT_DB_PASS=import_pass \
  -e CPU_IDLE_MIN=15 \
  -e ASYNC_WAIT=true -e ASYNC_WAIT_MAX=100 -e DUMP_WAIT_SECONDS=0.6 \
  adockero/mysqldump:tables-ssh-cpu
```

SSH 端口、密钥等参数放 `SSH_ARGS`，例如 `-e SSH_ARGS="-p 2222 -i /key"`。
