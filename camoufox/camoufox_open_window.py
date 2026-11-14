#!/usr/bin/env python3
"""Camoufox 保活窗口守护进程（独立于 launch_browser.py，由 open-window.sh 拉起）。

背景：launchServer 模式不会主动开浏览器窗口，没有任何窗口时 Xvfb(:99) 桌面
全黑，noVNC 页面自然黑屏。本守护进程作为 playwright 客户端
connect ws://127.0.0.1:9333 并 new_page() 打开一个内联提示页，让屏幕有画面。

行为：
  1. 单实例：pid 写入 /tmp/camoufox-open-window.pid；启动时检测到已有存活
     保活进程则直接退出（退出码 0），不开第二个窗口
  2. 连接 ws://127.0.0.1:9333（尊重 WS_PATH 环境变量，与 launch_browser.py
     同一套规范化逻辑）；服务未就绪时重试，最多约 15 秒，超时退出码 1
  3. new_page() 打开内联 data:text/html 提示页（Camoufox 已就绪 / ws 地址 /
     此窗口由保活进程持有 / 手动关闭窗口不影响自动化）
  4. 长期持有 sync_playwright 实例与 browser/page 引用，永不 close：
     进程活着窗口就一直在；SIGTERM/SIGINT 时干净退出（窗口随之消失，
     Playwright WS 自动化服务不受影响）
  5. 巡检：用户在 noVNC 里手动关掉该窗口后，约 10 秒内自动重新打开

日志：统一 [open-window] 前缀，逐行 flush（stdout 无缓冲），由 open-window.sh
重定向到 /var/log/camoufox-open-window.log。
"""

import os
import signal
import sys
import threading
import time
from pathlib import Path
from urllib.parse import quote

PID_FILE = Path("/tmp/camoufox-open-window.pid")
WS_PORT = 9333
CONNECT_TOTAL_TIMEOUT = 15  # 连接 WS 的总重试时长（秒）
REOPEN_CHECK_INTERVAL = 10  # 窗口被手动关闭后的重开巡检间隔（秒）

# ---------- WS 路径规范化（与 launch_browser.py 保持一致） ----------
# playwright 语义：wsPath 空则随机 GUID 路径，带值自动补前导 /；
# 空值一律当 "/"（根路径），此时连接地址就是 ws://127.0.0.1:9333
_ws_path = os.environ.get("WS_PATH", "/").strip()
if not _ws_path or _ws_path == "/":
    WS_ENDPOINT_SUFFIX = ""
else:
    WS_ENDPOINT_SUFFIX = _ws_path if _ws_path.startswith("/") else f"/{_ws_path}"
WS_URL = f"ws://127.0.0.1:{WS_PORT}{WS_ENDPOINT_SUFFIX}"


def log(msg: str) -> None:
    print(f"[open-window] {msg}", flush=True)


def _pid_alive(pid: int) -> bool:
    """os.kill(pid, 0) 探活：不存在返回 False；存在但无权限发信号视为存活"""
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def already_running() -> int:
    """返回已存活保活实例的 pid；无实例则返回 0（顺带清理陈旧 pid 文件）"""
    if not PID_FILE.exists():
        return 0
    try:
        pid = int(PID_FILE.read_text(encoding="utf-8").strip())
    except (OSError, ValueError) as e:
        log(f"pid 文件内容非法({e})，按无实例处理并清理: {PID_FILE}")
        PID_FILE.unlink(missing_ok=True)
        return 0
    if pid > 0 and pid != os.getpid() and _pid_alive(pid):
        return pid
    log(f"发现陈旧 pid 文件（pid={pid} 进程已不存在），清理: {PID_FILE}")
    PID_FILE.unlink(missing_ok=True)
    return 0


def hint_page_url() -> str:
    """内联提示页（data:text/html）：说明窗口用途与手动开关方法"""
    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Camoufox 已就绪</title>
<style>
  body {{ font-family: sans-serif; background: #1e2430; color: #e8eaed;
         display: flex; align-items: center; justify-content: center; }}
  .box {{ max-width: 640px; line-height: 1.7; }}
  code {{ background: #2d3442; padding: 2px 6px; border-radius: 4px; }}
  h1 {{ color: #7ee787; }}
</style></head>
<body><div class="box">
  <h1>&#9989; Camoufox 已就绪</h1>
  <ul>
    <li>Playwright WS 连接地址：<code>{WS_URL}</code>
        （从容器外连接时把 127.0.0.1 换成宿主机 IP）</li>
    <li>此窗口由保活进程持有（camoufox_open_window.py），仅用于保活/演示</li>
    <li>手动关掉此窗口<b>不影响自动化</b>；自动化连接 new_page 开的页面与它相互独立
        （守护进程稍后会自动重开本窗口）</li>
    <li>彻底关闭窗口：<code>docker exec &lt;容器名&gt; close-window.sh</code>；
        重新打开：<code>docker exec &lt;容器名&gt; open-window.sh</code></li>
  </ul>
</div></body>
</html>"""
    # data URL 用百分号编码，避免 HTML 里的特殊字符破坏 URL
    return "data:text/html;charset=utf-8," + quote(html)


def main() -> int:
    running_pid = already_running()
    if running_pid:
        log(f"保活窗口已在运行（pid={running_pid}，pid 文件 {PID_FILE}），本进程直接退出")
        return 0

    # SIGTERM/SIGINT -> 置位 stop，主循环 ≤1 秒内响应并干净退出
    stop = threading.Event()

    def _on_signal(signum, _frame) -> None:
        log(f"收到信号 {signal.Signals(signum).name}，保活窗口退出")
        stop.set()

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)

    PID_FILE.write_text(f"{os.getpid()}\n", encoding="utf-8")
    log(f"pid={os.getpid()} 已写入 {PID_FILE}")

    # 单实例确认后再导入 playwright（camoufox venv 自带 playwright）
    from playwright.sync_api import sync_playwright  # noqa: PLC0415

    playwright = sync_playwright().start()  # 长期持有，永不 stop/close

    # 连接 WS：未就绪则重试，总时长约 CONNECT_TOTAL_TIMEOUT 秒
    deadline = time.time() + CONNECT_TOTAL_TIMEOUT
    attempt = 0
    while True:
        attempt += 1
        try:
            log(f"第 {attempt} 次连接 {WS_URL} ...")
            browser = playwright.firefox.connect(WS_URL, timeout=5000)
            break
        except Exception as e:  # noqa: BLE001 连接失败重试；重试超时才退出（异常已记录）
            if time.time() >= deadline:
                log(f"连接 {WS_URL} 重试超过 {CONNECT_TOTAL_TIMEOUT} 秒仍失败，退出: "
                    f"{type(e).__name__}: {e}")
                return 1
            log(f"连接失败({type(e).__name__}: {e})，1 秒后重试 ...")
            time.sleep(1)

    log(f"已连接 Playwright WS: {WS_URL}")
    page = browser.new_page()  # 长期持有，永不 close
    page.goto(hint_page_url())
    log("保活窗口已打开（内联提示页，noVNC 应能看到画面）")

    # 常驻：1 秒粒度等停止信号；每隔 REOPEN_CHECK_INTERVAL 巡检窗口是否被手动关闭
    next_check = time.monotonic() + REOPEN_CHECK_INTERVAL
    while not stop.is_set():
        if stop.wait(1):
            break
        if time.monotonic() < next_check:
            continue
        next_check = time.monotonic() + REOPEN_CHECK_INTERVAL
        try:
            if page.is_closed():
                page = browser.new_page()
                page.goto(hint_page_url())
                log("检测到保活窗口被手动关闭，已重新打开")
        except Exception as e:  # noqa: BLE001 巡检失败仅记录，下一轮继续（异常已记录）
            log(f"窗口巡检异常({type(e).__name__}: {e})，下一轮继续巡检")

    # 干净退出：仅清理自己的 pid 文件；不 close 浏览器/页面（客户端断开后
    # 保活窗口消失，launchServer 与其他客户端的自动化页面不受影响）
    try:
        if PID_FILE.exists() and PID_FILE.read_text(encoding="utf-8").strip() == str(os.getpid()):
            PID_FILE.unlink()
            log(f"已清理 pid 文件 {PID_FILE}")
    except OSError as e:
        log(f"清理 pid 文件失败({e})，交由 close-window.sh 兜底")
    log("保活窗口进程退出（窗口已关闭，自动化服务不受影响）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
