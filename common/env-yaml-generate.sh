#!/usr/bin/env sh

# 用法: env-yaml-generate.sh <yaml_file_path>
# 示例: ENV_YAML_authers.0.name.0.username=user1 env-yaml-generate.sh config.yaml

yaml_file="$1"

if [ -z "$yaml_file" ]; then
  echo "错误: 请提供 YAML 文件路径作为第一个参数"
  exit 1
fi

# 如果文件不存在，创建空文件
if [ ! -f "$yaml_file" ]; then
  echo "{}" > "$yaml_file"
fi

# 检查 yq 是否安装
if ! command -v yq >/dev/null 2>&1; then
  echo "错误: 需要安装 yq 工具"
  exit 1
fi

# 遍历所有 ENV_YAML_ 开头的环境变量
for env in $(printenv | grep "^ENV_YAML_"); do
  # 分割变量名和值
  key=$(echo "$env" | cut -d= -f1)
  val=$(echo "$env" | cut -d= -f2-)
  
  # 去掉 ENV_YAML_ 前缀
  path="${key#ENV_YAML_}"
  # path=authers__0__auths__0__password
  # 将双下划线替换为点：authers__0__auths__0__password -> authers.0.auths.0.password
  path=$(echo "$path" | sed 's/__/\./g')
  
  # 将路径转换为 yq 格式: authers.0.name.0.username -> .authers[0].name[0].username
  yq_path=$(echo ".$path" | sed 's/\.\([0-9]\+\)/[\1]/g')
  
  # 使用 yq 更新 YAML 文件
  yq eval -i "$yq_path = \"$val\"" "$yaml_file"
done

echo "YAML 文件已更新: $yaml_file"
