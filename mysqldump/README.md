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



# adockero/mysqldump:tables-ssh-pv容器

通过SSH管道导出远程MySQL数据并导入本地数据库，支持MD5差异检测和并发控制。

## 环境要求

### 远端SSH服务器必须存在的命令
- `mpstat` - CPU监控工具（来自sysstat包）
- `pv` - 限制带宽

#### 常见也必须存在
- `mysql` - MySQL客户端
- `mysqldump` - MySQL导出工具
- `md5sum` - MD5校验工具
- `bash` - Shell环境
- 基础命令：`grep`, `awk`, `sed`, `cat`, `ls`, `ps`

## 环境变量

### 数据库连接（远端导出源）
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DB_USER` | 数据库用户名 | - |
| `DB_PASS` | 数据库密码 | - |
| `DB_HOST` | 数据库主机地址 | - |
| `DB_PORT` | 数据库端口 | 3306 |
| `DB_NAME` | 数据库名（可选） | - |

### 导入目标数据库
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `IMPORT_DB_USER` | 导入目标数据库用户名 | - |
| `IMPORT_DB_PASS` | 导入目标数据库密码 | - |
| `IMPORT_DB_HOST` | 导入目标数据库主机 | - |
| `IMPORT_ARGS` | 导入额外参数 | - |

### SSH连接
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SSH_USER` | SSH用户名 | - |
| `SSH_PASSWORD` | SSH密码 | - |
| `SSH_IP` | SSH服务器IP | - |
| `SSH_ARGS` | SSH额外参数 | - |
| `STRICT_HOST_KEY_CHECKING` | 是否严格主机密钥检查 | no |

### 并发控制
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `ASYNC_WAIT_MAX` | 最大并发导入进程数 | 100 |
| `ASYNC_WAIT_DB_MAX` | 最大并发导出库数 | 10 |
| `DUMP_PV` | pv限速 | 6m |
| `DUMP_WAIT_SECONDS` | 导入间隔等待秒数 | 0.6 |

### 资源限制
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `CPUQUOTA` | CPU配额限制（如：30%） | - |
| `IONICE_C` | IO优先级类别 | - |

### 其他
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `IGNORE_DATABASE` | 忽略的数据库 | - |
| `DUMP_ARGS` | mysqldump额外参数 | - |
| `DB_TABLE_HOST` | 表导出主机（默认同DB_HOST） | - |
| `DB_TABLE_PORT` | 表导出端口（默认同DB_PORT） | - |

## 工作原理

1. 通过SSH连接远端服务器执行mysqldump
2. 逐库逐表导出数据并计算MD5值
3. 对比历史MD5检测数据差异
4. 通过管道将变更表数据导入目标数据库
5. 支持并发控制和资源限制