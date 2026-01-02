#!/usr/bin/env sh

# 指定要执行的文件夹路径
folder="$1"

# 遍历文件夹中的所有sh文件
for file in "$folder"/*.sh
do
  # 检查文件是否存在并可执行
  if [ -f "$file" ] && [ -x "$file" ]
  then
    # 执行sh文件
    $2 "$file"
    # 内部实现
    # rm -f "$file"
  fi
done