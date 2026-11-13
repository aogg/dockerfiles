#!/usr/bin/env python3
"""Camoufox 浏览器启动器：调 camoufox 官方 Remote Server（camoufox.server.launch_server）。

职责：
  1. 生成/复用指纹：/data/fingerprint.json 首次生成后持久化，重启复用，保证身份稳定
  2. 组装 launch_server 参数（headless=False 显示在 Xvfb :99 上，noVNC 才能看到窗口）
  3. 调 camoufox.server.launch_server(port=9333, ws_path=WS_PATH, ...) 启动 Playwright WS 服务器
     （任意语言的 playwright 客户端用 firefox.connect("ws://ip:9333") 连接；本镜像不用 CDP）
  4. 等待 9333 端口就绪 -> 写 /data/camoufox-info.json 并打印 ws:// 连接地址与 noVNC 地址
  5. 收到 SIGTERM/SIGINT 转 KeyboardInterrupt，由 launch_server 内部优雅关闭 Node 服务器

launch_server 是同步阻塞调用（内部拉起 playwright driver 自带的 Node 进程跑 launchServer.js，
阻塞到服务器退出）。参数 port/ws_path/host 经 **kwargs 透传给 playwright 的 launchServer：
  - ws_path=""(空) 在 playwright 里是"随机 GUID 路径"，连不上根路径；
    所以本镜像把默认 WS_PATH 规范化为 "/"（根路径），保证 ws://ip:9333 可直连。
  - playwright 的 launchServer 默认只绑 localhost，docker -p 端口映射过不来；
    本镜像固定传 host="0.0.0.0"（绑公网地址后 playwright 也会自动关闭 Host 校验）。

API 以镜像内实际安装的 camoufox 包（pip 最新 0.5.x）源码为准，旧版（browserforge 时代）兜底。
"""

import json
import os
import random
import re
import signal
import socket
import sys
import threading
import time
from pathlib import Path

# ---------- 环境变量 ----------
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
SCREEN_SIZE = os.environ.get("SCREEN_SIZE", "1366x768").strip()
LOCALE = os.environ.get("LOCALE", "en-US").strip()
GEOIP = os.environ.get("GEOIP", "false").strip().lower() in ("1", "true", "yes", "on")
# 空 = windows|macos|linux 随机；可指定单个 windows/macos/linux，或用 | 分隔的组合
FINGERPRINT_OS = os.environ.get("FINGERPRINT_OS", "").strip()
# WS 服务路径：空或 "/" = 根路径（连 ws://ip:9333）；其他值加前导 /，如 camoufox -> /camoufox
WS_PATH = os.environ.get("WS_PATH", "/").strip()
EXTRA_FIREFOX_ARGS = os.environ.get("EXTRA_FIREFOX_ARGS", "").strip()
DEBUG = os.environ.get("DEBUG", "false").strip().lower() in ("1", "true", "yes", "on")
DISPLAY = os.environ.get("DISPLAY", ":99")

# 容器内端口固定：5900 VNC | 6080 noVNC | 9333 Playwright WS，靠 docker -p 映射
WS_PORT = 9333
VNC_PORT = 5900
NOVNC_PORT = 6080

FINGERPRINT_FILE = DATA_DIR / "fingerprint.json"
INFO_FILE = DATA_DIR / "camoufox-info.json"

# ---------- 解析分辨率 ----------
_m = re.match(r"^(\d+)x(\d+)$", SCREEN_SIZE)
if _m:
    SCREEN_W, SCREEN_H = int(_m.group(1)), int(_m.group(2))
else:
    print(f"[launch_browser] SCREEN_SIZE='{SCREEN_SIZE}' 非法，回退为 1366x768")
    SCREEN_W, SCREEN_H = 1366, 768

# ---------- WS 路径规范化 ----------
# playwright 语义：wsPath 空则用随机 GUID 路径；带值则自动补前导 /。
# 镜像默认要"ws://ip:9333 直连根路径"，所以空值一律当 "/"。
def normalize_ws_path(value: str) -> str:
    if not value or value == "/":
        return "/"
    return value if value.startswith("/") else f"/{value}"


WS_PATH_NORM = normalize_ws_path(WS_PATH)


def log(msg: str) -> None:
    print(f"[launch_browser] {msg}", flush=True)


# ---------- 指纹：生成 / 复用 ----------
def parse_os_list() -> list:
    """FINGERPRINT_OS -> os 列表；空则随机 windows/macos/linux"""
    if not FINGERPRINT_OS:
        return ["windows", "macos", "linux"]
    names = [s.strip().lower() for s in FINGERPRINT_OS.split("|") if s.strip()]
    valid = {"windows", "macos", "linux", "win", "mac", "lin"}
    alias = {"win": "windows", "mac": "macos", "lin": "linux"}
    names = [alias.get(n, n) for n in names]
    bad = [n for n in names if n not in valid]
    if bad or not names:
        raise SystemExit(f"[launch_browser] FINGERPRINT_OS='{FINGERPRINT_OS}' 非法，"
                         f"只支持 windows/macos/linux，可用 | 分隔多个随机抽取")
    return names


def generate_fingerprint_compat(os_list: list) -> dict:
    """按镜像内实际安装的 camoufox 包版本生成指纹：
    - 0.5.x: fpgen（camoufox.fingerprints.generate_fingerprint，原生支持 os 列表与
      屏幕约束无解时自动回退，见 0.5.9 fingerprints.py）
    - 0.4.x: browserforge（camoufox.fingerprints.FingerprintGenerator）兜底"""
    try:
        from camoufox.fingerprints import Screen, generate_fingerprint  # noqa: PLC0415
    except ImportError:
        # 旧版（browserforge 时代）兜底
        from camoufox.fingerprints import Screen, FingerprintGenerator  # type: ignore  # noqa: PLC0415
        log("camoufox 包为旧版（browserforge 时代），用 FingerprintGenerator 生成")
        gen = FingerprintGenerator(
            browser="firefox",
            os=os_list,
            screen=Screen(max_width=SCREEN_W, max_height=SCREEN_H),
        )
        return gen.generate().resolve()  # browserforge Fingerprint -> dict

    log(f"用 camoufox 内置 fpgen 生成指纹，候选 OS={os_list}，屏幕上限 {SCREEN_W}x{SCREEN_H}")
    # 注意：fpgen(1.3.0) 对 os 列表（camoufox 转成 lambda 谓词）实测会抛
    # InvalidConstraints: 'yielded no possible values for os'，单值正常。
    # 所以多 OS 随机在这里自行抽取一个（随机性等价；结果持久化后身份固定）。
    chosen_os = random.choice(os_list)
    try:
        return generate_fingerprint(
            os=chosen_os,
            screen=Screen(max_width=SCREEN_W, max_height=SCREEN_H),
        )
    except Exception as e:
        # 部分组合（如 macOS 与 ≤768 高的屏幕上限）在指纹模型里联合无解，会抛
        # InvalidConstraints/RestrictiveConstraints。此时去掉屏幕上限重试
        # （camoufox 官方对 InvalidConstraints 也是同样回退策略），窗口若超出
        # Xvfb 分辨率由 Firefox 自行收缩，不影响指纹一致性。
        if type(e).__name__ not in ("InvalidConstraints", "RestrictiveConstraints"):
            raise
        log(f"屏幕上限 {SCREEN_W}x{SCREEN_H} 与 os={chosen_os} 在指纹模型中无解，"
            f"去掉屏幕上限重新生成 ({type(e).__name__})")
        return generate_fingerprint(os=chosen_os)


def load_or_create_fingerprint() -> dict:
    """首次生成后持久化，重启复用（身份随 /data 卷而稳定）"""
    if FINGERPRINT_FILE.exists():
        try:
            fp = json.loads(FINGERPRINT_FILE.read_text(encoding="utf-8"))
            if isinstance(fp, dict) and fp:
                log(f"复用已持久化指纹: {FINGERPRINT_FILE}")
                return fp
            log("指纹文件内容为空/非法，将重新生成")
        except (OSError, ValueError) as e:
            log(f"指纹文件读取失败({e})，将重新生成")

    fingerprint = generate_fingerprint_compat(parse_os_list())
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    FINGERPRINT_FILE.write_text(json.dumps(fingerprint, ensure_ascii=False, indent=2),
                                encoding="utf-8")
    log(f"指纹已保存: {FINGERPRINT_FILE}")
    return fingerprint


# ---------- WS 就绪探测 + 状态文件 ----------
def ws_endpoint_path() -> str:
    """对外连接的路径部分：根路径时直接 ws://ip:9333，带值时 ws://ip:9333<路径>"""
    return "" if WS_PATH_NORM == "/" else WS_PATH_NORM


def write_info(ready: bool, error: str = "") -> None:
    """写 /data/camoufox-info.json（启动状态信息）"""
    info = {
        "ready": ready,
        "ws_url": f"ws://127.0.0.1:{WS_PORT}{ws_endpoint_path()}",
        "ws_path": WS_PATH_NORM,
        "novnc_url": f"http://127.0.0.1:{NOVNC_PORT}/vnc.html?autoconnect=true",
        "vnc_address": f"127.0.0.1:{VNC_PORT}",
        "ports": {"playwright_ws": WS_PORT, "vnc": VNC_PORT, "novnc": NOVNC_PORT},
        "screen": f"{SCREEN_W}x{SCREEN_H}",
        "locale": LOCALE,
        "geoip": GEOIP,
        "error": error,
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        INFO_FILE.write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
        log(f"状态文件已写入: {INFO_FILE}")
    except OSError as e:
        log(f"状态文件写入失败({e})，不影响服务")


def wait_ws_ready(timeout: int = 180) -> bool:
    """等待 Playwright WS 端口监听（TCP 可连即视为就绪），超时返回 False（仅告警不退出）"""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", WS_PORT), timeout=2):
                return True
        except OSError:
            time.sleep(1)
    return False


# ---------- 信号：SIGTERM/SIGINT -> KeyboardInterrupt，launch_server 内部会优雅关闭 ----------
def _signal_to_interrupt(signum, _frame):
    raise KeyboardInterrupt(f"收到信号 {signum}，通知 WS 服务器优雅退出")


# ---------- 主流程 ----------
def main() -> None:
    log(f"数据目录={DATA_DIR} 分辨率={SCREEN_W}x{SCREEN_H} locale={LOCALE} "
        f"geoip={GEOIP} ws_port={WS_PORT} ws_path={WS_PATH_NORM} display={DISPLAY}")

    signal.signal(signal.SIGTERM, _signal_to_interrupt)
    signal.signal(signal.SIGINT, signal.default_int_handler)

    fingerprint = load_or_create_fingerprint()
    ua = (fingerprint.get("navigator") or {}).get("userAgent", "未知")
    log(f"指纹 userAgent: {ua}")

    # camoufox 官方 Remote Server（API 以镜像内实际安装的包源码为准）
    from camoufox.server import launch_server  # noqa: PLC0415

    server_kwargs = {
        # headful 显示在 Xvfb :99 上（noVNC 能看到真实窗口）；virtual_display 让
        # camoufox 给浏览器进程注入 DISPLAY/GDK_BACKEND=x11
        "headless": False,
        "virtual_display": DISPLAY,
        # 指纹（复用持久化的）与指纹 OS 候选
        "fingerprint": fingerprint,
        "os": parse_os_list(),
        # 指纹屏幕上限约束在生成时已应用；这里不传 screen/window 覆盖，保持持久化身份完整
        "locale": LOCALE or None,
        "geoip": True if GEOIP else None,
        "args": EXTRA_FIREFOX_ARGS.split(),
        "i_know_what_im_doing": True,
        "debug": DEBUG,
        # server 专属：端口 / 路径 / 绑定地址（port、ws_path、host 经 **kwargs 透传给
        # playwright launchServer；host 必须绑 0.0.0.0，否则 docker -p 映射连不进来）
        "port": WS_PORT,
        "ws_path": WS_PATH_NORM,
        "host": "0.0.0.0",
    }
    log("launch_server 参数: " + json.dumps(
        {k: (v if k not in ("fingerprint",) else f"<dict {len(v)}键>") for k, v in server_kwargs.items()},
        ensure_ascii=False, default=str))

    # 后台线程等 9333 就绪后写状态文件并打印访问地址；主线程阻塞在 launch_server 里
    def _ready_reporter() -> None:
        if wait_ws_ready():
            write_info(ready=True)
            print("=" * 64, flush=True)
            print(f"  Playwright WS : ws://<宿主机IP>:{WS_PORT}{ws_endpoint_path()}"
                  f"   (playwright firefox.connect)", flush=True)
            print(f"  noVNC         : http://<宿主机IP>:{NOVNC_PORT}/vnc.html?autoconnect=true", flush=True)
            print(f"  VNC           : <宿主机IP>:{VNC_PORT}", flush=True)
            print("=" * 64, flush=True)
        else:
            write_info(ready=False, error=f"等待 WS 端口 {WS_PORT} 就绪超时")
            log(f"警告：等待 WS 端口 {WS_PORT} 就绪超时（服务器可能仍在启动，继续观察日志）")

    threading.Thread(target=_ready_reporter, daemon=True).start()

    log("启动 Camoufox Remote Server（阻塞运行，直到收到退出信号或服务器异常退出）...")
    try:
        launch_server(**server_kwargs)
    except KeyboardInterrupt as e:
        log(f"退出：{e}")
        return
    # launch_server 正常不会返回；走到这里说明 Node 服务器进程异常退出，
    # 抛 RuntimeError 使容器以非零码退出（交给 docker restart 策略重启）
    raise SystemExit(1)


if __name__ == "__main__":
    main()
