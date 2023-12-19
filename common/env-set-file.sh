#!/usr/bin/env sh

#file=$ENV_SET_FILE_PATH
file=$(cd $(dirname $ENV_SET_FILE_PATH) && pwd)/$(basename $ENV_SET_FILE_PATH)

# 读取所有环境变量
for env in $(printenv); do

  # 分割变量
  key=$(echo $env | cut -d= -f1)
  val=$(echo $env | cut -d= -f2-)

  # echo "$key => $val"

  # 判断key变量是否存在前置
  if echo "$key" | grep -q "^${ENV_PREFIX}"; then


    # 去掉前缀
    key="${key#$ENV_PREFIX}"

    echo "${key}=${val}" >> $file

  fi

done

