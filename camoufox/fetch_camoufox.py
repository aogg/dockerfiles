#!/usr/bin/env python3
"""构建期 Camoufox 浏览器下载辅助脚本（可选镜像加速），用法等价 `python -m camoufox fetch`。

用法（Dockerfile 内）：
    yes | python fetch_camoufox.py            # 安装配对 pinned 版本
    yes | python fetch_camoufox.py <版本号>    # 安装指定版本，如 official/135.0-beta.25

环境变量 CAMOUFOX_ASSET_MIRROR：
    非空时，把 camoufox 对 github.com 大文件（浏览器 zip 约 1.2GB / GeoIP mmdb）的下载
    改写为 <镜像前缀>/<原始GitHub URL>（如 https://ghfast.top）。下载完成后仍由 camoufox
    按 GitHub 发布的 sha256 严格校验，镜像只影响传输路径，不影响内容完整性。
    GitHub Actions 等境外构建环境无需设置（直连快）；境内自建机建议设置。

    已知可用的镜像前缀（2026-11 实测，时效性自行验证）：
      https://ghfast.top   （约 1.6MB/s）
      https://gh-proxy.com （约 0.14MB/s）
"""

import os
import sys


def _install_mirror_patch(mirror: str) -> None:
    """把 github.com 请求改写为走镜像前缀。

    camoufox fetch 过程中所有下载最终都经 camoufox.pkgman 里的 requests.get：
    - pkgman.webdl（浏览器 zip / GeoIP mmdb / fpgen 模型 zip，geolocation 与 fpgen_model
      都是从 pkgman import 同一个 webdl 函数）
    - manifest.json（requests.get 直连 browser_download_url）
    所以只需替换 pkgman 引用的 requests.get 一个点（模块对象共享，webdl 内部调用同样命中）。
    镜像只改写传输路径（如 https://ghfast.top/https://github.com/...），下载完成后仍按
    GitHub 发布的 sha256 严格校验，内容完整性不受镜像影响。api.github.com 不改写
    （pinned 版本安装不需要 API，且镜像不代理 API）。"""
    import requests

    _orig_get = requests.get

    def get_via_mirror(url, *args, **kwargs):
        # 幂等保护：已带镜像前缀的 URL 不再二次改写
        if isinstance(url, str) and url.startswith("https://github.com/") \
                and not url.startswith(mirror):
            url = f"{mirror}/{url}"
        return _orig_get(url, *args, **kwargs)

    requests.get = get_via_mirror
    print(f"[fetch_camoufox] github 大文件下载走镜像加速: {mirror}", flush=True)


def main() -> None:
    mirror = (os.environ.get("CAMOUFOX_ASSET_MIRROR") or "").strip().rstrip("/")
    if mirror:
        _install_mirror_patch(mirror)

    from camoufox.__main__ import cli

    # 转成 camoufox CLI 的 argv：fetch_camoufox.py [版本号] -> camoufox fetch [版本号]
    sys.argv = [sys.argv[0], "fetch"] + sys.argv[1:]
    cli()


if __name__ == "__main__":
    main()
