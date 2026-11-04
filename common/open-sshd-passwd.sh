#!/usr/bin/env sh
set -e  # 遇到错误立即退出


# ===================== 基础配置与版本检测 =====================
# 定义默认 SSH 端口（未传参时用 22）
SSHD_PORT=${SSHD_PORT:-22}
# 检测 OpenSSH 主版本号（提取数字部分，如 8.4 → 8，6.6 → 6）
SSH_VERSION=$(ssh -V 2>&1 | awk '{gsub(/,|_p[0-9]+/,""); print $1}' | cut -d'.' -f1)
# 兼容旧版本输出格式（部分系统 ssh -V 输出不同）
if [ -z "$SSH_VERSION" ] || ! echo "$SSH_VERSION" | grep -q '[0-9]'; then
    SSH_VERSION=$(ssh -V 2>&1 | awk '{print $NF}' | cut -d'_' -f1 | cut -d'.' -f1)
fi
# 确保版本号为数字（兜底：默认按高版本处理）
if ! echo "$SSH_VERSION" | grep -q '^[0-9]\+$'; then
    SSH_VERSION=7
fi

echo "=== 检测到 OpenSSH 主版本：$SSH_VERSION ==="


if [ ! -f /etc/ssh/docker-run-open-sshd-passwd-sh.tmp ];then


# ===================== 生成 SSH 主机密钥（版本兼容） =====================
# 生成 RSA 密钥（全版本兼容，强制 4096 位更安全）
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "=== 生成 RSA 主机密钥 ==="
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa -b 4096
else
    echo "=== RSA 主机密钥已存在，跳过生成 ==="
fi

# 生成 ED25519 密钥（OpenSSH ≥6.5 支持，优先推荐）
if [ "$SSH_VERSION" -ge 6 ]; then
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        echo "=== 生成 ED25519 主机密钥 ==="
        ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
    else
        echo "=== ED25519 主机密钥已存在，跳过生成 ==="
    fi
fi

# 仅 OpenSSH <7.0 时尝试生成 DSA 密钥（已废弃，仅兜底）
if [ "$SSH_VERSION" -lt 7 ]; then
    if [ ! -f /etc/ssh/ssh_host_dsa_key ]; then
        echo "=== 生成 DSA 主机密钥（仅兼容旧版本） ==="
        ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa || {
            echo "警告：DSA 密钥生成失败，跳过（不影响核心功能）"
        }
    else
        echo "=== DSA 主机密钥已存在，跳过生成 ==="
    fi
else
    echo "=== OpenSSH ≥7.0，跳过废弃的 DSA 密钥生成 ==="
    # 删除旧的 DSA 密钥配置（避免 sshd 加载报错）
    sed -i '/ssh_host_dsa_key/d' /etc/ssh/sshd_config 2>/dev/null || true
fi

# ===================== 初始化 SSH 运行环境 =====================
# 创建 sshd 运行目录（避免启动报错）
echo "=== 初始化 SSH 运行目录 ==="
mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd

# ===================== 修改 sshd 配置（兼容全版本） =====================
echo "=== 调整 sshd 配置 ==="
# 1. UsePrivilegeSeparation：OpenSSH 7.5+ 已废弃该参数，避免配置报错
if [ "$SSH_VERSION" -lt 7 ] || [ "$(echo "$SSH_VERSION" | cut -d'.' -f2)" -lt 5 ]; then
    sed -i "s/^UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config 2>/dev/null || true
else
    sed -i "/^UsePrivilegeSeparation/d" /etc/ssh/sshd_config 2>/dev/null || true
fi

# 2. 禁用 PAM（保持原有逻辑）
sed -i "s/^UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config 2>/dev/null || true

# 3. 允许 root 登录（保持原有逻辑）
sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config 2>/dev/null || true

# 4. 启用密码登录（保持原有逻辑）
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config 2>/dev/null || true

# 4. 启用密码登录（保持原有逻辑）
sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config 2>/dev/null || true

# 5. 启用授权密钥文件（保持原有逻辑）
sed -i "s/^#\?AuthorizedKeysFile.*/AuthorizedKeysFile .ssh/authorized_keys/g" /etc/ssh/sshd_config 2>/dev/null || true

# ==========新增开启端口转发配置==========
if [ "$SSH_ALLOW_TCP_FORWARDING" = "1" ]; then
    sed -i '/^AllowTcpForwarding/d' /etc/ssh/sshd_config || true
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config || true
    # 如果你只允许访问172.19.0.90:2222就启用下面一行注释版本
    # echo 'PermitOpen 172.19.0.90:2222' >> /etc/ssh/sshd_config
fi


# ===================== 注入 PROFILE_ENV_* 环境变量到 /etc/profile =====================
# 说明：容器内所有以 PROFILE_ENV_ 开头的环境变量，去掉前缀后写入 /etc/profile，
#       供 sshd 派生的登录 shell 使用
#       例如 PROFILE_ENV_JAVA_HOME=/usr/local/java → export JAVA_HOME='/usr/local/java'
PROFILE_ENV_PREFIX="PROFILE_ENV_"
PROFILE_MARK_BEGIN="# >>> sshd PROFILE_ENV_* begin >>>"
PROFILE_MARK_END="# <<< sshd PROFILE_ENV_* end <<<"

# 清理上一次写入的配置块（保证脚本重复执行不会重复追加）
if [ -f /etc/profile ] && grep -qF "$PROFILE_MARK_BEGIN" /etc/profile; then
    echo "=== 清理 /etc/profile 中旧的 PROFILE_ENV_* 配置 ==="
    awk -v begin="$PROFILE_MARK_BEGIN" -v end="$PROFILE_MARK_END" '
        $0 == begin { skip = 1 }
        skip != 1 { print }
        $0 == end { skip = 0 }
    ' /etc/profile > /etc/profile.tmp && mv /etc/profile.tmp /etc/profile
fi

if env | grep -q "^${PROFILE_ENV_PREFIX}"; then
    echo "=== 注入 PROFILE_ENV_* 环境变量到 /etc/profile ==="
    {
        echo "$PROFILE_MARK_BEGIN"
        env | grep "^${PROFILE_ENV_PREFIX}" | sort | while IFS='=' read -r _key _value; do
            _name=${_key#"$PROFILE_ENV_PREFIX"}
            # 跳过空名或非法变量名
            if ! printf '%s\n' "$_name" | grep -q -e '^[A-Za-z_][A-Za-z0-9_]*$'; then
                echo "警告：跳过非法变量名 ${_key}（忽略）" >&2
                continue
            fi
            # 单引号包裹并转义内部单引号，避免 $ / 反引号在 shell 中被二次展开
            _escaped=$(printf '%s' "$_value" | sed "s/'/'\\\\''/g")
            printf "export %s='%s'\n" "$_name" "$_escaped"
            echo "  - ${_name}" >&2
        done
        echo "$PROFILE_MARK_END"
    } >> /etc/profile
else
    echo "=== 未检测到 PROFILE_ENV_* 环境变量，跳过 /etc/profile 注入 ==="
fi

# ===================== 设置 root 密码（传参时） =====================
if [ -n "$SSHD_PASSWORD" ]; then
    echo "=== 设置 root 密码 ==="
    echo "root:${SSHD_PASSWORD}" | chpasswd
else
    echo "=== 未传入 SSHD_PASSWORD，跳过密码设置 ==="
fi


    touch /etc/ssh/docker-run-open-sshd-passwd-sh.tmp
fi

# ===================== 启动 sshd 服务 =====================
echo "=== 启动 sshd 服务（端口：$SSHD_PORT） ==="
# 查找 sshd 可执行文件（兼容不同系统路径）
SSHD_BIN=$(which sshd || echo "/usr/sbin/sshd")
# 启动并输出详细日志（-e），指定端口，传递额外参数
if [ "$1" = "-D" ]; then
    echo "第一个参数是 -D"
    exec "$SSHD_BIN" -e -p "$SSHD_PORT" "$@"
else
    "$SSHD_BIN" -e -p "$SSHD_PORT" "$@" &
fi

echo "=== sshd 服务已启动 ==="
