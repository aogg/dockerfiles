#!/usr/bin/env bash
# Camoufox 容器入口：
#   Xvfb(:99) -> x11vnc(:5900) -> websockify/noVNC(:6080) -> Camoufox Remote Server(Playwright WS :9333)
# 所有子进程由本脚本统一管理，收到 SIGTERM/SIGINT 后按序清理并退出。
set -u

DATA_DIR="${DATA_DIR:-/data}"
SCREEN_SIZE="${SCREEN_SIZE:-1366x768}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
export DISPLAY="${DISPLAY:-:99}"

# ---------- 时区（TZ 或 TIMEZONE，如 Asia/Shanghai） ----------
TZ_VAL="${TIMEZONE:-${TZ:-}}"
if [ -n "${TZ_VAL}" ] && [ -f "/usr/share/zoneinfo/${TZ_VAL}" ]; then
    ln -sf "/usr/share/zoneinfo/${TZ_VAL}" /etc/localtime
    echo "${TZ_VAL}" > /etc/timezone
    echo "[start.sh] 时区已设置为：${TZ_VAL}"
fi

# ---------- 解析分辨率 ----------
SCREEN_W="${SCREEN_SIZE%x*}"
SCREEN_H="${SCREEN_SIZE#*x}"
if ! [[ "${SCREEN_W}" =~ ^[0-9]+$ ]] || ! [[ "${SCREEN_H}" =~ ^[0-9]+$ ]] \
    || [ "${SCREEN_W}" -lt 400 ] || [ "${SCREEN_H}" -lt 300 ]; then
    echo "[start.sh] SCREEN_SIZE='${SCREEN_SIZE}' 非法，回退为 1366x768"
    SCREEN_W=1366
    SCREEN_H=768
fi

mkdir -p "${DATA_DIR}"

XVFB_PID=""
X11VNC_PID=""
WEBSOCKIFY_PID=""
SERVER_PID=""

# ---------- 清理函数：按服务器 -> noVNC -> VNC -> Xvfb 顺序停 ----------
cleanup() {
    echo "[start.sh] 收到退出信号，正在停止所有子进程..."
    local pid
    for pid in "${SERVER_PID}" "${WEBSOCKIFY_PID}" "${X11VNC_PID}" "${XVFB_PID}"; do
        [ -n "${pid}" ] && kill "${pid}" 2>/dev/null
    done
    # 给 WS 服务器最多 8 秒优雅退出时间（launch_server 收 SIGTERM 会优雅关闭浏览器）
    if [ -n "${SERVER_PID}" ]; then
        for _ in $(seq 1 40); do
            kill -0 "${SERVER_PID}" 2>/dev/null || break
            sleep 0.2
        done
    fi
    # 还活着的强杀
    for pid in "${SERVER_PID}" "${WEBSOCKIFY_PID}" "${X11VNC_PID}" "${XVFB_PID}"; do
        if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
            kill -9 "${pid}" 2>/dev/null
        fi
    done
    wait 2>/dev/null
    echo "[start.sh] 清理完成，退出"
}
trap cleanup TERM INT

echo "[start.sh] 启动 Xvfb :99 分辨率 ${SCREEN_W}x${SCREEN_H}"
Xvfb "${DISPLAY}" -screen 0 "${SCREEN_W}x${SCREEN_H}x24" -nolisten tcp &
XVFB_PID=$!

# x11vnc：VNC_PASSWORD 为空则免密
VNC_PASS_ARGS=(-nopw)
if [ -n "${VNC_PASSWORD}" ]; then
    echo "[start.sh] VNC 已启用密码认证"
    VNC_PASS_ARGS=(-passwd "${VNC_PASSWORD}")
else
    echo "[start.sh] VNC_PASSWORD 为空，VNC 免密（仅建议内网使用）"
fi
echo "[start.sh] 启动 x11vnc 端口 5900"
x11vnc -display "${DISPLAY}" -rfbport 5900 -forever -shared "${VNC_PASS_ARGS[@]}" &
X11VNC_PID=$!

# websockify + noVNC 网页服务
echo "[start.sh] 启动 noVNC(websockify) 端口 6080"
websockify --web /usr/share/novnc 6080 localhost:5900 &
WEBSOCKIFY_PID=$!

# Camoufox Remote Server（launch_browser.py 内部生成/复用指纹并等待 9333 就绪）
python3 /usr/local/bin/launch_browser.py &
SERVER_PID=$!

# 等待 Playwright WS 端口就绪（最多 180 秒，仅用于日志提示；launch_browser.py 内部同样会等待）
echo "[start.sh] 等待 Playwright WS 端口 9333 就绪..."
WS_WAITED=0
until (exec 3<>"/dev/tcp/127.0.0.1/9333") 2>/dev/null; do
    sleep 1
    WS_WAITED=$((WS_WAITED + 1))
    # 服务器进程提前退出就不用再等了
    if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
        break
    fi
    if [ "${WS_WAITED}" -ge 180 ]; then
        echo "[start.sh] 警告：等待 9333 超时（服务器可能仍在启动，继续观察日志）"
        break
    fi
done
if (exec 3<>"/dev/tcp/127.0.0.1/9333") 2>/dev/null; then
    echo "[start.sh] Playwright WS 端口 9333 已就绪（耗时约 ${WS_WAITED} 秒），连接地址 ws://<宿主机IP>:9333"
fi

# ---------- 保活窗口（AUTO_OPEN_WINDOW 控制，默认开） ----------
# launchServer 模式不会主动开浏览器窗口：无窗口时 Xvfb(:99) 全黑，noVNC 无画面。
# AUTO_OPEN_WINDOW=false/0/no（大小写不敏感）关闭；其余值或未设置一律视为开启。
AUTO_OPEN_WINDOW_VAL="${AUTO_OPEN_WINDOW:-true}"
case "${AUTO_OPEN_WINDOW_VAL,,}" in
    false|0|no)
        echo "[start.sh] AUTO_OPEN_WINDOW=${AUTO_OPEN_WINDOW_VAL}: 不自动打开保活窗口（noVNC 初始黑屏属预期，可随时 docker exec <容器名> open-window.sh 打开）"
        ;;
    *)
        echo "[start.sh] AUTO_OPEN_WINDOW=${AUTO_OPEN_WINDOW_VAL}: 自动打开保活窗口"
        /usr/local/bin/open-window.sh \
            || echo "[start.sh] 警告：保活窗口启动失败（不影响 WS 自动化，可稍后手动 docker exec <容器名> open-window.sh 重试）"
        ;;
esac

# 前台等待服务器进程退出；其退出码就是容器退出码
wait "${SERVER_PID}"
EXIT_CODE=$?
echo "[start.sh] Camoufox 服务器进程已退出，退出码 ${EXIT_CODE}"
cleanup
exit "${EXIT_CODE}"
