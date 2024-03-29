# 解决原镜像bug
1、原镜像camil/mysqldump


# 完整支持参数传参给mysqldump
```bash
docker run --rm -v $PWD:/mysqldump -e DB_NAME=db_name -e DB_PASS=db_pass -e DB_USER=db_user -e DB_HOST=db_host camil/mysqldump --skip-lock-tables --add-drop-table --extended-insert
```
