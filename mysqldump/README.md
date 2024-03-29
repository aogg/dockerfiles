# 解决原镜像bug
1、原镜像camil/mysqldump


# 完整支持参数传参给mysqldump
```bash
docker run --rm -v $PWD:/mysqldump -e DB_NAME=db_name -e DB_PASS=db_pass -e DB_USER=db_user -e DB_HOST=db_host camil/mysqldump --skip-lock-tables --add-drop-table --extended-insert
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