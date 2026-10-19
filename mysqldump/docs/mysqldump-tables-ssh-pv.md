# adockero/mysqldump:tables-ssh-pv

tables-ssh 家族的 pv 限速版。通过 SSH 只在远端执行 mysql 查询（取库表列表、结构、CHECKSUM），导出和导入都在容器内用 `mysqldump | pv 限速 | mysql` 流水线完成，远端不落盘。支持表级 CHECKSUM 差异对比、表结构 MD5 对比、大表分页同步、远端 CPU 监控和库/表两级并发控制。

流程图见 [dump-import.md5.pv.flow.md](./dump-import.md5.pv.flow.md)。

## 构建信息

| 项 | 值 |
|---|---|
| 基础镜像 | `alpine` |
| 客户端 | `mysql-client`（MariaDB 版，含 mysqldump / mysql） |
| 其他软件 | bash、openssh-client、sshpass、pv（构建参数 `APK_ARG=pv`） |
| 入口脚本 | `dump-import.md5.pv.sh`（构建参数 `FILE_ARG`） |
| 入口 | `/bin/sh -c $ENTRYPOINT_RUN`，固定执行入口脚本，无需覆盖 entrypoint |

## 与同家族其他 tag 的差异

- [tables-ssh](./mysqldump-tables-ssh.md)：MD5 算法在远端执行并落盘，用 diff 对比，远端必须有 mysqldump
- [tables-ssh-cpu](./mysqldump-tables-ssh-cpu.md)：同 tables-ssh，加远端 CPU 空闲率保护
- [tables-ssh-pv-mysql](./mysqldump-tables-ssh-pv-mysql.md)：与本镜像脚本相同，客户端换成原版 MySQL（debian:bullseye-slim 基础镜像）

## 工作流程

1. sshpass + ssh 连接远端，ControlMaster 复用连接
2. 启动远端 mpstat 监控，实时记录远端 CPU 空闲率和 mysqldump 进程数，监控进程挂掉自动重启
3. 库级并发：同时处理的库不超过 `ASYNC_WAIT_DB_MAX`，并参考远端 mysqldump 进程数放行
4. 每表先对比表结构 MD5（去掉 AUTO_INCREMENT 后计算），结构有差异或目标表不存在时先同步表结构
5. 数据对比：
   - 数值主键且行数达到 `PAGE_SYNC_MIN_ROWS`、分页同步开启时：按主键分页（每页 `PAGE_SIZE` 行），逐页 CRC32 校验，只导差异页，结束后删除目标表超出源表最大主键的数据并同步 AUTO_INCREMENT
   - 其他表：整表 `CHECKSUM TABLE` 对比，有差异才 `mysqldump --replace | pv -L $DUMP_PV | mysql`
   - 配置了 `SYNC_WHERE` 分组 where 过滤的表：行数统计/导出/校验都带条件，跳过整表 CHECKSUM 改按条件同步（见下方环境变量说明）
6. 单表操作失败自动重试 3 次
7. 全部结束后等待进程收尾（只统计运行态进程），清理临时目录

远端 SSH 服务器必须存在：`mysql` 客户端、`mpstat`（sysstat 包）、`bash`。pv 在容器内执行，镜像已安装。

`DB_HOST_BY_SSH`（默认同 `DB_HOST`）是远端连数据库用的地址，远端可能需要内网 IP；`DB_TABLE_HOST`（默认同 `DB_HOST`）是容器内 mysqldump 导出用的地址，两者可分开设置。

## 环境变量

### env 文件加载

配置优先级：已导出的环境变量（`docker run -e` 等）> env 文件 > 脚本内默认值。

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ENV_FILE` | 显式指定 env 文件路径 | - |

未设置 `ENV_FILE` 时自动加载脚本同目录的 `.env`；容器内脚本是 `/dump-import.md5.pv.sh`，即自动加载 `/.env`，需要把文件挂载进去。

env 文件格式：每行 `KEY=VALUE`，支持 `#` 注释、空行、`export ` 前缀、成对的单/双引号；非法变量名跳过并提示。只填充未设置或为空的变量，不覆盖 `-e` 传入的真实环境变量。

```bash
# 挂载为自动加载的 /.env
docker run --rm -v $PWD/tables-ssh-pv.env:/.env -e SSH_IP=... adockero/mysqldump:tables-ssh-pv
# 或显式指定 ENV_FILE
docker run --rm -v $PWD:/conf -e ENV_FILE=/conf/tables-ssh-pv.env adockero/mysqldump:tables-ssh-pv
```

### 数据库连接

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_USER` | 数据库用户名，必填 | - |
| `DB_PASS` | 数据库密码，必填 | - |
| `DB_HOST` | 数据库主机，必填 | - |
| `DB_PORT` | 数据库端口 | 3306 |
| `DB_NAME` | 脚本读取但未使用 | - |
| `DB_TABLE_HOST` | 容器内 mysqldump 导出用主机 | 同 `DB_HOST` |
| `DB_TABLE_PORT` | 容器内 mysqldump 导出用端口 | 同 `DB_PORT` |
| `DB_HOST_BY_SSH` | SSH 远端执行 mysql 查询用的主机（可能需要内网 IP） | 同 `DB_HOST` |
| `DB_PORT_BY_SSH` | SSH 远端执行 mysql 查询用的端口 | 同 `DB_PORT` |

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

### 并发与限速

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ASYNC_WAIT` | 设置后异步并发执行，结束时等待全部进程完成 | - |
| `ASYNC_WAIT_MAX` | 最大并发表数量 | 100 |
| `ASYNC_WAIT_DB_MAX` | 最大并发库数量 | 10 |
| `DUMP_PV` | pv 限速，如 `6m` | 6m |
| `DUMP_WAIT_SECONDS` | 表处理间隔秒数 | 0.6 |

### 分页同步

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `PAGE_SYNC_ENABLED` | 是否启用分页同步（1 启用，0 禁用） | 1 |
| `PAGE_SIZE` | 每页数据量（行数） | 5000 |
| `PAGE_SYNC_TABLES` | 指定启用分页同步的表，逗号分隔，支持 `库名.表名`；为空则所有符合条件的表 | - |
| `PAGE_SYNC_MIN_ROWS` | 分页同步的最小行数阈值，低于此值走整表对比 | 5000 |

### 分组 where 过滤

按组给表配 where 条件，组号 `NN` 支持任意多组，两个变量成对配置才生效：

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SYNC_WHERE_TABLES_NN` | 第 NN 组表清单，逗号分隔，条目支持 `表名`、`库名.表名`、`库名.*`、`*` | - |
| `SYNC_WHERE_STR_NN` | 第 NN 组 where 条件，如 `is_deleted=0 AND created_at>'2024-01-01'` | - |

```bash
-e SYNC_WHERE_TABLES_01="orders,order_items,db2.logs" -e SYNC_WHERE_STR_01="is_deleted=0 AND created_at>'2024-01-01'" \
-e SYNC_WHERE_TABLES_02="db3.*" -e SYNC_WHERE_STR_02="level_id<4"
```

- 命中优先级：`db.table` > `db.*` > `table` > `*`；多个组同时命中取更精确的，同精度取组号小的
- 生效范围：远端行数统计、`mysqldump --where` 导出导入、分页同步的分页查询与 CRC32 校验
- 配置了 where 的表跳过整表 `CHECKSUM TABLE` 快速路径，改用 `--replace` 按条件同步
- 分页同步末尾的「删除目标端超范围数据」和「AUTO_INCREMENT 回写」跳过，避免误删被条件排除但目标库已存在的行
- 条件内字符串值用单引号，不要用双引号（SSH 远端 SQL 转义困难）

### 过滤与其他

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `IGNORE_DATABASE` | 忽略的一个数据库名 | - |
| `IGNORE_TABLES` | 忽略的表名，逗号分隔 | - |
| `MYSQL_TABLES_ONLY_SYNC` | 只同步列出的表，逗号分隔，支持 `库名.表名`；为空则全部同步 | - |
| `DUMP_ARGS` | mysqldump 额外参数 | - |
| `CPUQUOTA` | 预留变量，当前脚本仅赋值给 `RUN_LIMIT_START`，未实际生效 | - |
| `IONICE_C` | 预留变量，当前脚本仅赋值给 `RUN_LIMIT_START`，未实际生效 | - |
| `MYSQL_DATA_DIR` | 预留变量，当前脚本未使用 | - |

## 容器用法

```bash
docker run --rm \
  -e DB_HOST=10.0.0.5 -e DB_PORT=3306 -e DB_USER=db_user -e DB_PASS=db_pass \
  -e SSH_IP=10.0.0.5 -e SSH_USER=ssh_user -e SSH_PASSWORD=ssh_pass \
  -e DB_HOST_BY_SSH=172.16.0.5 \
  -e IMPORT_DB_HOST=172.17.0.1 -e IMPORT_DB_USER=import_user -e IMPORT_DB_PASS=import_pass \
  -e ASYNC_WAIT=true -e ASYNC_WAIT_MAX=100 -e ASYNC_WAIT_DB_MAX=10 \
  -e DUMP_PV=6m -e DUMP_WAIT_SECONDS=0.6 \
  adockero/mysqldump:tables-ssh-pv
```

SSH 端口、密钥等参数放 `SSH_ARGS`，例如 `-e SSH_ARGS="-p 2222 -i /key"`。
