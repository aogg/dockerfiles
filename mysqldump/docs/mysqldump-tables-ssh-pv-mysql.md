# adockero/mysqldump:tables-ssh-pv-mysql

tables-ssh 家族的 pv 原版客户端版。入口脚本、环境变量、用法与 [tables-ssh-pv](./mysqldump-tables-ssh-pv.md) 完全一致，只是基础镜像和客户端不同：基于 `debian:bullseye-slim`，安装 `default-mysql-client`（原版 MySQL 客户端），而 tables-ssh-pv 基于 alpine 的 MariaDB 客户端。

流程图见 [dump-import.md5.pv.flow.md](./dump-import.md5.pv.flow.md)。

## 构建信息

| 项 | 值 |
|---|---|
| 基础镜像 | `debian:bullseye-slim` |
| 客户端 | `default-mysql-client`（原版 MySQL 客户端，含 mysqldump / mysql） |
| 其他软件 | bash、openssh-client、sshpass、procps、pv（构建参数 `APK_ARG=pv`） |
| 入口脚本 | `dump-import.md5.pv.sh`（构建参数 `FILE_ARG`） |
| 入口 | `/bin/sh -c $ENTRYPOINT_RUN`，固定执行入口脚本，无需覆盖 entrypoint |

## 与同家族其他 tag 的差异

与 [tables-ssh-pv](./mysqldump-tables-ssh-pv.md) 相比：

- 基础镜像 `debian:bullseye-slim`，客户端为原版 MySQL，dump 输出格式与 MySQL 官方一致，适合对 MariaDB 客户端导出格式有兼容问题（如 `--skip-ssl`、特定语句差异）的场景
- 脚本、环境变量、用法完全一致

工作流程、远端要求、完整环境变量表见 [mysqldump-tables-ssh-pv.md](./mysqldump-tables-ssh-pv.md)。远端 SSH 服务器必须存在：`mysql` 客户端、`mpstat`（sysstat 包）、`bash`。

## 容器用法

```bash
docker run --rm \
  -e DB_HOST=10.0.0.5 -e DB_PORT=3306 -e DB_USER=db_user -e DB_PASS=db_pass \
  -e SSH_IP=10.0.0.5 -e SSH_USER=ssh_user -e SSH_PASSWORD=ssh_pass \
  -e DB_HOST_BY_SSH=172.16.0.5 \
  -e IMPORT_DB_HOST=172.17.0.1 -e IMPORT_DB_USER=import_user -e IMPORT_DB_PASS=import_pass \
  -e ASYNC_WAIT=true -e ASYNC_WAIT_MAX=100 -e ASYNC_WAIT_DB_MAX=10 \
  -e DUMP_PV=6m -e DUMP_WAIT_SECONDS=0.6 \
  adockero/mysqldump:tables-ssh-pv-mysql
```

SSH 端口、密钥等参数放 `SSH_ARGS`，例如 `-e SSH_ARGS="-p 2222 -i /key"`。
