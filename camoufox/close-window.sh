#!/usr/bin/env bash
# 手动关闭 Camoufox 保活窗口（与 open-window.sh 配对）
# 用法：docker exec <容器名> close-window.sh
# 行为：按 pid 文件结束保活进程（SIGTERM，最多等 5 秒，未退则 kill -9），
#       清理 pid 文件并输出结果；窗口随之关闭（noVNC 变黑屏属预期）。
set -u

PID_FILE="/tmp/camoufox-open-window.pid"

if [ ! -f "${PID_FILE}" ]; then
    echo "[close-window] 保活窗口未在运行（无 pid 文件 ${PID_FILE}），无需关闭"
    exit 0
fi

PID="$(cat "${PID_FILE}" 2>/dev/null)"
if ! [[ "${PID}" =~ ^[0-9]+$ ]]; then
    echo "[close-window] pid 文件内容非法('${PID}')，直接清理 pid 文件"
    rm -f "${PID_FILE}"
    exit 0
fi

if ! kill -0 "${PID}" 2>/dev/null; then
    echo "[close-window] pid=${PID} 进程已不存在（陈旧 pid 文件），清理 pid 文件"
    rm -f "${PID_FILE}"
    exit 0
fi

echo "[close-window] 结束保活进程 pid=${PID} ..."
kill "${PID}" 2>/dev/null
# 稍等确认退出（最多 5 秒）
for _ in $(seq 1 10); do
    kill -0 "${PID}" 2>/dev/null || break
    sleep 0.5
done
if kill -0 "${PID}" 2>/dev/null; then
    echo "[close-window] 5 秒未退出，强制 kill -9"
    kill -9 "${PID}" 2>/dev/null
    sleep 0.5
fi

rm -f "${PID_FILE}"
echo "[close-window] 保活窗口已关闭（屏幕无窗口 = noVNC 黑屏属预期；自动化 WS 服务不受影响）"
exit 0
