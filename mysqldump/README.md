# mysqldump

adockero/mysqldump 系列镜像的索引与快速上手。镜像由 [.github/workflows/mysqldump.yml](../.github/workflows/mysqldump.yml) 构建，`*.md` 改动不触发构建。每个镜像的完整说明在 [docs/](./docs/) 下。

# 解决原镜像bug
1、原镜像camil/mysqldump
2、原文档说明，https://hub.docker.com/r/camil/mysqldump


# 完整支持参数传参给mysqldump
```bash
docker run --rm -v $PWD:/mysqldump -e DB_NAME=db_name -e DB_PASS=db_pass -e DB_USER=db_user -e DB_HOST=db_host -e ALL_DATABASES=true -e ASYNC_WAIT=true \
camil/mysqldump --skip-lock-tables --add-drop-table --extended-insert
```


# 环境变量

```
# 支持异步并发执行，然后等待所有
ENV ASYNC_WAIT ""
# 操作所有数据库，忽略默认系统数据库
ENV ALL_DATABASES ""
# 手动忽略的数据库
ENV IGNORE_DATABASE ""

ENV DB_HOST ""
ENV DB_NAME ""
ENV DB_PASS ""
ENV DB_USER ""

```


# 镜像列表

| 镜像 tag | 说明 | 文档 |
|----------|------|------|
| `adockero/mysqldump:8` | 基础版，按库导出，基于 mysql:8-debian | [./docs/mysqldump-8.md](./docs/mysqldump-8.md) |
| `adockero/mysqldump:5.7` | 基础版，按库导出，基于 mysql:5.7-debian | [./docs/mysqldump-5.7.md](./docs/mysqldump-5.7.md) |
| `adockero/mysqldump`（latest） | 基础版，按库导出，基于 mysql:debian | [./docs/mysqldump-latest.md](./docs/mysqldump-latest.md) |
| `adockero/mysqldump:tables-ssh` | SSH 远端逐表 MD5 差异迁移 | [./docs/mysqldump-tables-ssh.md](./docs/mysqldump-tables-ssh.md) |
| `adockero/mysqldump:tables-ssh-cpu` | tables-ssh + 远端 CPU 空闲率保护 | [./docs/mysqldump-tables-ssh-cpu.md](./docs/mysqldump-tables-ssh-cpu.md) |
| `adockero/mysqldump:tables-ssh-pv` | 容器内 pv 限速流水线，支持分页同步 | [./docs/mysqldump-tables-ssh-pv.md](./docs/mysqldump-tables-ssh-pv.md) |
| `adockero/mysqldump:tables-ssh-pv-mysql` | tables-ssh-pv + 原版 MySQL 客户端 | [./docs/mysqldump-tables-ssh-pv-mysql.md](./docs/mysqldump-tables-ssh-pv-mysql.md) |
| `adockero/mysqldump:tables-5.7` | 逐表导出/导入/直连迁移，不经过 SSH | [./docs/mysqldump-tables-5.7.md](./docs/mysqldump-tables-5.7.md) |

pv 脚本流程图：[docs/dump-import.md5.pv.flow.md](./docs/dump-import.md5.pv.flow.md)


# 容器用法

## 基础版（mysqldump:8 / 5.7 / latest）

```bash
# 导出单个数据库
docker run --rm -v $PWD:/mysqldump -e DB_NAME=db_name -e DB_PASS=db_pass -e DB_USER=db_user -e DB_HOST=db_host \
adockero/mysqldump --skip-lock-tables --add-drop-table --extended-insert

# 导出所有数据库，异步并发
docker run --rm -v $PWD:/mysqldump -e DB_HOST=db_host -e DB_USER=db_user -e DB_PASS=db_pass -e ALL_DATABASES=true -e ASYNC_WAIT=true \
adockero/mysqldump

# 导入 /mysqldump 下所有 .sql 文件
docker run --rm -v $PWD:/mysqldump -e DB_HOST=local_host -e DB_USER=db_user -e DB_PASS=db_pass -e ALL_DATABASES=true \
--entrypoint /import.sh \
adockero/mysqldump
```

## tables-ssh 家族

```bash
docker run --rm -e DB_HOST=db_host -e DB_PORT=3306 -e DB_USER=db_user -e DB_PASS=db_pass \
-e SSH_IP=ssh_ip -e SSH_USER=ssh_user -e SSH_PASSWORD=ssh_pass \
-e IMPORT_DB_HOST=import_host -e IMPORT_DB_USER=import_user -e IMPORT_DB_PASS=import_pass \
-e ASYNC_WAIT=true \
adockero/mysqldump:tables-ssh-pv
```

## tables 家族

```bash
# 逐表导出
docker run --rm -v $PWD:/mysqldump -e DB_HOST=db_host -e DB_USER=db_user -e DB_PASS=db_pass -e ASYNC_WAIT=true \
adockero/mysqldump:tables-5.7

# 逐表导入
docker run --rm -v $PWD:/mysqldump -e DB_HOST=local_host -e DB_USER=db_user -e DB_PASS=db_pass -e ASYNC_WAIT=true \
--entrypoint /import.sh \
adockero/mysqldump:tables-5.7
```


# 各镜像详细说明

<details>
<summary>基础版：mysqldump:8 / 5.7 / latest 的差异与环境变量</summary>

三个 tag 共用同一 Dockerfile（入口 `/dump.sh`，导入用 `--entrypoint /import.sh`），只有基础镜像不同：

| 镜像 | 基础镜像 |
|------|----------|
| `adockero/mysqldump:8` | `mysql:8-debian` |
| `adockero/mysqldump:5.7` | `mysql:5.7-debian` |
| `adockero/mysqldump`（latest） | `mysql:debian`，跟随官方标签不锁版本 |

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_HOST` | 数据库主机，必填 | - |
| `DB_PORT` | 数据库端口 | 3306 |
| `DB_USER` | 数据库用户名，必填 | - |
| `DB_PASS` | 数据库密码，必填 | - |
| `DB_NAME` | 数据库名；`ALL_DATABASES` 为空时必填 | - |
| `ALL_DATABASES` | 设置后操作所有库，跳过系统库和 `_` 开头的库 | - |
| `IGNORE_DATABASE` | 额外忽略的一个库名 | - |
| `ASYNC_WAIT` | 设置后异步并发执行，结束时等待全部进程完成 | - |

镜像名后的参数原样传给 mysqldump（导出）或 mysql（导入）。

详见 [docs/mysqldump-8.md](./docs/mysqldump-8.md)、[docs/mysqldump-5.7.md](./docs/mysqldump-5.7.md)、[docs/mysqldump-latest.md](./docs/mysqldump-latest.md)。

</details>

<details>
<summary>tables-ssh 家族：四个镜像的差异与公共环境变量</summary>

通过 SSH 连远端做逐表差异迁移，入口固定，无需覆盖 entrypoint。

| 镜像 | 入口脚本 | 客户端 | 特点 |
|------|----------|--------|------|
| `tables-ssh` | dump-import.md5.sh | MariaDB（alpine） | 远端 mysqldump 落盘算 MD5，diff 出差异表后导入 |
| `tables-ssh-cpu` | dump-import.md5.cpu.sh | MariaDB（alpine） | 加远端 CPU 空闲率保护，低于 `CPU_IDLE_MIN` 不发起新导出 |
| `tables-ssh-pv` | dump-import.md5.pv.sh | MariaDB（alpine）+pv | 远端只跑查询，容器内 `mysqldump \| pv \| mysql` 流水线，支持分页同步 |
| `tables-ssh-pv-mysql` | dump-import.md5.pv.sh | 原版 MySQL（debian） | 同 tables-ssh-pv，客户端为原版 MySQL |

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_HOST` / `DB_USER` / `DB_PASS` | 源数据库连接，必填 | - |
| `DB_PORT` | 数据库端口 | 3306 |
| `SSH_IP` / `SSH_USER` / `SSH_PASSWORD` | SSH 连接，必填 | - |
| `SSH_ARGS` | SSH 额外参数，如 `-p 2222` | - |
| `STRICT_HOST_KEY_CHECKING` | 是否严格主机密钥检查 | no |
| `IMPORT_DB_HOST` / `IMPORT_DB_USER` / `IMPORT_DB_PASS` | 导入目标数据库 | - |
| `IMPORT_ARGS` | 导入 mysql 额外参数 | - |
| `ASYNC_WAIT` | 异步并发执行 | - |
| `ASYNC_WAIT_MAX` | 最大并发进程/表数 | 100 |
| `ASYNC_WAIT_DB_MAX` | 最大并发库数（仅 pv 版） | 10 |
| `IGNORE_DATABASE` | 忽略的一个库名 | - |
| `IGNORE_DATABASE_TABLES` | 忽略的表，逗号分隔（md5/cpu/pv 版） | - |
| `IGNORE_TABLES` | 忽略的表，逗号分隔（仅 pv 版） | - |
| `MYSQL_TABLES_ONLY_SYNC` | 只同步列出的表（仅 pv 版） | - |
| `DUMP_ARGS` | mysqldump 额外参数 | - |
| `CPU_IDLE_MIN` | 远端 CPU 空闲率下限（仅 cpu 版） | 15 |
| `DUMP_WAIT_SECONDS` | 表间隔秒数（cpu/pv 版） | 0.6 |
| `DUMP_PV` | pv 限速（仅 pv 版） | 6m |

pv 版的完整环境变量（分页同步、`DB_TABLE_HOST`、`DB_HOST_BY_SSH` 等）见 [docs/mysqldump-tables-ssh-pv.md](./docs/mysqldump-tables-ssh-pv.md)。

</details>

<details>
<summary>tables 家族：tables-5.7 的环境变量与脚本</summary>

`tables-5.7` 是 tables 家族唯一推送的 tag（workflow 里 step 名为 tables 的构建推的也是这个 tag，最终以 `mysql:5.7-debian` 那次构建为准），基于 `mysql:5.7-debian`，直连数据库，不经过 SSH。

内含三个脚本：`/dump.sh`（默认入口，逐表导出到 `/mysqldump/$db/$table.sql`）、`/import.sh`（逐表导入，`--entrypoint /import.sh`）、`/dump-import.sh`（逐表管道直连迁移，`--entrypoint /dump-import.sh`）。

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_HOST` / `DB_USER` / `DB_PASS` | 源数据库连接，必填 | - |
| `ASYNC_WAIT` | 异步并发执行 | - |
| `ASYNC_WAIT_MAX` | 最大并发进程数 | 100 |
| `IGNORE_DATABASE` | 忽略的一个库名 | - |
| `IGNORE_DATABASE_TABLES` | 忽略的表，逗号分隔 | - |
| `ONLY_DATABASE` | 只同步列出的库（仅 dump-import.sh） | - |
| `IMPORT_DATABASE_SUFFIX` | 导入库名后缀（仅 dump-import.sh） | - |
| `IMPORT_DB_HOST` / `IMPORT_DB_USER` / `IMPORT_DB_PASS` | 导入目标数据库（仅 dump-import.sh） | - |

详见 [docs/mysqldump-tables-5.7.md](./docs/mysqldump-tables-5.7.md)。

</details>

<details>
<summary>adockero/mysqldump:tables-ssh-pv 容器的环境要求与工作原理</summary>

通过SSH管道导出远程MySQL数据并导入本地数据库，支持MD5差异检测和并发控制。

### 环境要求

#### 远端SSH服务器必须存在的命令
- `mpstat` - CPU监控工具（来自sysstat包）

#### 常见也必须存在
- `mysql` - MySQL客户端
- `bash` - Shell环境
- 基础命令：`grep`, `awk`, `sed`, `cat`, `ls`, `ps`

`pv` 在容器内执行流水线，镜像已安装。

### 环境变量

#### 数据库连接（远端导出源）
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_USER` | 数据库用户名 | - |
| `DB_PASS` | 数据库密码 | - |
| `DB_HOST` | 数据库主机地址 | - |
| `DB_PORT` | 数据库端口 | 3306 |
| `DB_NAME` | 数据库名（可选） | - |

#### 导入目标数据库
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `IMPORT_DB_USER` | 导入目标数据库用户名 | - |
| `IMPORT_DB_PASS` | 导入目标数据库密码 | - |
| `IMPORT_DB_HOST` | 导入目标数据库主机 | - |
| `IMPORT_ARGS` | 导入额外参数 | - |

#### SSH连接
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SSH_USER` | SSH用户名 | - |
| `SSH_PASSWORD` | SSH密码 | - |
| `SSH_IP` | SSH服务器IP | - |
| `SSH_ARGS` | SSH额外参数 | - |
| `STRICT_HOST_KEY_CHECKING` | 是否严格主机密钥检查 | no |

#### 并发控制
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ASYNC_WAIT_MAX` | 最大并发导入进程数 | 100 |
| `ASYNC_WAIT_DB_MAX` | 最大并发导出库数 | 10 |
| `DUMP_PV` | pv限速 | 6m |
| `DUMP_WAIT_SECONDS` | 导入间隔等待秒数 | 0.6 |

#### 资源限制
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `CPUQUOTA` | CPU配额限制（如：30%） | - |
| `IONICE_C` | IO优先级类别 | - |

#### 其他
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `IGNORE_DATABASE` | 忽略的数据库 | - |
| `DUMP_ARGS` | mysqldump额外参数 | - |
| `DB_TABLE_HOST` | 表导出主机（默认同DB_HOST） | - |
| `DB_TABLE_PORT` | 表导出端口（默认同DB_PORT） | - |

### 工作原理

1. 通过SSH连接远端服务器执行mysqldump
2. 逐库逐表导出数据并计算MD5值
3. 对比历史MD5检测数据差异
4. 通过管道将变更表数据导入目标数据库
5. 支持并发控制和资源限制

</details>
