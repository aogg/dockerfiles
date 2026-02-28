# dump-import.md5.pv.sh 流程图

## 整体流程

```mermaid
flowchart TD
    A[开始] --> B[环境变量初始化]
    B --> C{SSH连接验证}
    C -->|失败| D[退出]
    C -->|成功| E{首次运行?}
    E -->|是| F[初始化目录结构]
    E -->|否| G[继续执行]
    F --> G
    G --> H[启动CPU空闲率监控<br/>异步进程]
    H --> I[获取数据库列表]
    I --> J[循环处理每个数据库]
```

## 数据库处理流程

```mermaid
flowchart TD
    A[开始处理数据库] --> B{是否为系统库<br/>或忽略库?}
    B -->|是| C[跳过该库]
    B -->|否| D{并发库数量<br/>>= ASYNC_WAIT_DB_MAX?}
    D -->|是| E{远端mysqldump<br/>数量 < ASYNC_WAIT_DB_MAX?}
    E -->|是| F[等待确认后继续]
    E -->|否| G[等待2秒]
    G --> D
    D -->|否| H[获取该库的表列表]
    F --> H
    H --> I[循环处理每个表]
    I --> J[等待当前库所有表处理完成]
    J --> K[更新完成日志]
    K --> L{还有更多库?}
    L -->|是| A
    L -->|否| M[进入最终等待]
```

## 表处理流程（并发）

```mermaid
flowchart TD
    A[开始处理表] --> B{本地并发数<br/>< ASYNC_WAIT_MAX?}
    B -->|否| C[等待1秒]
    C --> B
    B -->|是| D[SSH远程执行表检查]
    D --> E{MYSQL_DATA_DIR<br/>存在?}
    E -->|是| F[检查表文件修改时间]
    E -->|否| G[直接导出表]
    F --> G
    G --> H[导出表数据<br/>计算MD5]
    H --> I{MD5文件存在?}
    I -->|否| J[标记为新表]
    I -->|是| K{MD5有差异<br/>或修改时间改变?}
    K -->|是| L[标记为差异表]
    K -->|否| M[无差异跳过]
    J --> N[异步导入表数据]
    L --> N
    M --> O[处理下一表]
    N --> O
```

## 表导入流程

```mermaid
flowchart TD
    A[检测到差异表] --> B[本地mysqldump导出]
    B --> C[pv限速传输]
    C --> D[导入到目标数据库]
    D --> E[记录导入结束时间]
    E --> F[继续处理下一个差异]
```

## 最终清理流程

```mermaid
flowchart TD
    A[所有库处理完成] --> B{检测mysqldump<br/>进程是否存在?}
    B -->|是| C[等待1秒]
    C --> B
    B -->|否| D[SSH远程清理]
    D --> E[移动temp目录到diff]
    E --> F[输出结束时间]
    F --> G[脚本结束]
```

## 关键参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `DB_PORT` | 3306 | 数据库端口 |
| `ASYNC_WAIT_MAX` | 100 | 最大并发表数量 |
| `ASYNC_WAIT_DB_MAX` | 10 | 最大并发库数量 |
| `DUMP_PV` | 6m | pv限速 |
| `DUMP_WAIT_SECONDS` | 0.6 | 表处理间隔秒数 |
| `CPUQUOTA` | - | systemd CPU配额限制 |
| `IONICE_C` | - | ionice IO优先级 |

## 并发控制策略

1. **库级别并发控制**: 同时处理的库数量不超过 `ASYNC_WAIT_DB_MAX`
2. **表级别并发控制**: 同时运行的 mysqldump 进程不超过 `ASYNC_WAIT_MAX`
3. **远端监控**: 实时监控远端 mysqldump 进程数量，避免过载
4. **资源限制**: 支持 systemd CPU配额 和 ionice IO优先级 限制
