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

# 5. 启用授权密钥文件（保持原有逻辑）
sed -i "s/^#\?AuthorizedKeysFile.*/AuthorizedKeysFile .ssh/authorized_keys/g" /etc/ssh/sshd_config 2>/dev/null || true

# ===================== 设置 root 密码（传参时） =====================
if [ -n "$SSH_PWD" ]; then
    echo "=== 设置 root 密码 ==="
    echo "root:${SSH_PWD}" | chpasswd
else
    echo "=== 未传入 SSH_PWD，跳过密码设置 ==="
fi

# ===================== 启动 sshd 服务 =====================
echo "=== 启动 sshd 服务（端口：$SSHD_PORT） ==="
# 查找 sshd 可执行文件（兼容不同系统路径）
SSHD_BIN=$(which sshd || echo "/usr/sbin/sshd")
# 启动并输出详细日志（-e），指定端口，传递额外参数
"$SSHD_BIN" -e -p "$SSHD_PORT" "$@" &