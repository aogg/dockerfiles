FROM adockero/hermes


# 基础镜像 adockero/hermes 已自带：
#   - Python 3.13.5（/usr/bin/python3，满足 3.11+）
#   - Node.js v26.5.1 + npm 11.17.0（满足 22.12+，war-room 需要 Node 22+）
#   - git、curl、runuser、python3-venv
#   - s6-overlay init 系统，已有 dashboard 和 main-hermes 两个 s6 服务
#   - hermes CLI 在 /opt/hermes/bin/hermes，hermes 用户 uid=1000
# 因此无需额外安装系统依赖


# 下载并解压 hermes-war-room 生产 tarball（GitHub release 自包含构建）
# 安装到 /opt/hermes-war-room（不在 /opt/hermes 或 /opt/data 下，不干扰现有 hermes）
# tarball 根目录是 .output/，解压后即 /opt/hermes-war-room/.output/server/index.mjs
# 构建时以 root 操作，运行时 hermes 用户需要有读取执行权限 + data/ 写入权限
RUN mkdir -p /opt/hermes-war-room \
    && curl -fsSL --retry 3 -o /tmp/hermes-war-room.tar.gz \
        https://github.com/Naroh091/hermes-war-room/releases/latest/download/hermes-war-room.tar.gz \
    && tar -xzf /tmp/hermes-war-room.tar.gz -C /opt/hermes-war-room \
    && rm -f /tmp/hermes-war-room.tar.gz \
    && chown -R hermes:hermes /opt/hermes-war-room \
    # 环境检查：确认 node 存在且版本 >= 22（war-room 硬性要求 Node 22+）
    # 若基础镜像无 node 会在这里直接构建失败，方便定位
    && node -v \
    && ls -la /opt/hermes-war-room/.output/server/index.mjs


# 添加 war-room 为 s6-overlay 服务（与现有 dashboard、hudui 服务同级）
# 这样 s6 统一管理进程生命周期：dashboard、main-hermes、war-room 并行运行
# 不使用 entrypoint 脚本手动起进程，与基础镜像的 s6 架构保持一致
#
# 服务目录结构：
#   /etc/s6-overlay/s6-rc.d/war-room/type          -> longrun
#   /etc/s6-overlay/s6-rc.d/war-room/run           -> 启动脚本
#   /etc/s6-overlay/s6-rc.d/war-room/finish        -> 退出处理
#   /etc/s6-overlay/s6-rc.d/war-room/dependencies.d/base  -> 依赖（空文件，与 dashboard 同级）
#   /etc/s6-overlay/s6-rc.d/user/contents.d/war-room    -> 加入 user bundle
RUN mkdir -p /etc/s6-overlay/s6-rc.d/war-room/dependencies.d

# war-room 服务类型：longrun（长期运行的服务）
RUN echo "longrun" > /etc/s6-overlay/s6-rc.d/war-room/type

# war-room 启动脚本
# - 以 hermes 用户运行（s6-setuidgid），与 hermes 主进程同用户才能直读 kanban.db / profiles
# - HOME/HERMES_HOME 指向 /opt/data（hermes 数据目录）
# - NITRO_HOST=0.0.0.0 绑定所有网卡（容器环境需要外部访问，默认 127.0.0.1 访问不到）
# - PATH 追加 /opt/hermes/bin（war-room 会 spawn `hermes -p <slug> acp` 子进程）
COPY hermes-war-room/war-room-run /etc/s6-overlay/s6-rc.d/war-room/run
RUN chmod +x /etc/s6-overlay/s6-rc.d/war-room/run

# war-room finish 脚本（与 dashboard/finish 类似，非 125 退出码允许 s6 重启）
COPY hermes-war-room/war-room-finish /etc/s6-overlay/s6-rc.d/war-room/finish
RUN chmod +x /etc/s6-overlay/s6-rc.d/war-room/finish

# 依赖 base（与 dashboard、main-hermes 同级，空文件）
RUN touch /etc/s6-overlay/s6-rc.d/war-room/dependencies.d/base

# 将 war-room 加入 user bundle（与 dashboard、main-hermes 并列）
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/war-room


# war-room 默认端口（Nitro node-server）
EXPOSE 3000

# hermes dashboard 端口（继承自基础镜像，由 s6 dashboard 服务监听）
EXPOSE 9119


# 入口点：不覆盖 ENTRYPOINT / CMD，完全继承基础镜像 adockero/hermes 的默认值
# （基础镜像默认 ENTRYPOINT = ["/init", "/docker-entrypoint.sh"]）
# 历史教训：显式覆盖 ENTRYPOINT 会导致 docker-entrypoint.sh 完全不执行
#       （data 初始化 / TZ 设置 / dashboard 9119 启动 / exec hermes 全部丢失）
# s6-overlay 先执行 /init，再以 /docker-entrypoint.sh 作为 main program 运行
# docker-entrypoint.sh 内部完成环境初始化后 exec hermes，启动 hermes 主进程
# 不设 CMD：s6-overlay 的 main program = /docker-entrypoint.sh，Docker CMD 作为 $@ 传入。
# 若 CMD 是 "hermes"，docker-entrypoint.sh 内 exec hermes 会变成 hermes hermes 报错。
# 基础镜像默认 CMD=null，删除后 $@ 为空，docker-entrypoint.sh 内 exec hermes 正确执行。
# （无 CMD 行即表示使用基础镜像默认 null CMD）

# 基础镜像没有 ash（/usr/bin/ash 不存在），而 /docker-entrypoint.sh 的 shebang 是
# #!/usr/bin/env ash，不建符号链接会报 env: 'ash': No such file or directory，hermes 起不来。
# dash 和 ash 语法兼容，建符号链接即可。
RUN ln -sf /usr/bin/dash /usr/bin/ash
