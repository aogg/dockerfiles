#!/usr/bin/env bash
# 手动打开 Camoufox 保活窗口（与 close-window.sh 配对）
# 用法：docker exec <容器名> open-window.sh
# 行为：保活进程已在运行则提示并退出 0；否则 nohup 后台拉起
#       camoufox_open_window.py（日志 -> /var/log/camoufox-open-window.log），
#       等 2 秒确认进程存活后输出结果。
set -u

PID_FILE="/tmp/camoufox-open-window.pid"
LOG_FILE="/var/log/camoufox-open-window.log"
PY_SCRIPT="/usr/local/bin/camoufox_open_window.py"

# venv python 优先（镜像 PATH 已含 /opt/camoufox-venv/bin，这里显式指认更稳）
if [ -x /opt/camoufox-venv/bin/python ]; then
    PYBIN="/opt/camoufox-venv/bin/python"
else
    PYBIN="$(command -v python3)"
fi

alive() {
    local pid
    [ -f "${PID_FILE}" ] || return 1
    pid="$(cat "${PID_FILE}" 2>/dev/null)"
    [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
}

if alive; then
    echo "[open-window] 保活窗口已在运行（pid=$(cat "${PID_FILE}")），无需重复启动"
    exit 0
fi

echo "[open-window] 启动保活窗口进程（日志: ${LOG_FILE}）..."
rm -f "${PID_FILE}"
nohup "${PYBIN}" -u "${PY_SCRIPT}" >> "${LOG_FILE}" 2>&1 &

# 等 2 秒确认进程真的活着（pid 文件由守护进程启动后自行写入）
sleep 2
if alive; then
    echo "[open-window] 保活窗口已启动（pid=$(cat "${PID_FILE}")），窗口即将出现在屏幕上"
    exit 0
fi

echo "[open-window] 启动失败，最近日志如下："
tail -n 20 "${LOG_FILE}" 2>/dev/null || echo "（无日志文件 ${LOG_FILE}）"
exit 1
