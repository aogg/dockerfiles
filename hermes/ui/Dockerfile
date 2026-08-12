FROM adockero/hermes


# 基础镜像 adockero/hermes 已自带：
#   - Python 3.13.5（/usr/bin/python3，满足 3.11+）
#   - Node.js v26.5.1 + npm 11.17.0（满足 22.12+）
#   - git、curl、runuser、python3-venv
#   - s6-overlay init 系统，已有 dashboard 和 main-hermes 两个 s6 服务
#   - hermes CLI 在 /opt/hermes/bin/hermes，hermes 用户 uid=1000
# 因此无需额外安装系统依赖


# 克隆并安装 hermes-hudui
# 安装到 /opt/hermes-hudui（不在 /opt/hermes 或 /opt/data 下，不干扰现有 hermes）
# 构建时以 root 操作，运行时 hermes 用户需要有读取和执行权限
RUN git clone https://github.com/joeynyc/hermes-hudui.git /opt/hermes-hudui \
    && cd /opt/hermes-hudui \
    && python3 -m venv venv \
    && ./venv/bin/python -m ensurepip --upgrade \
    && ./venv/bin/pip install --upgrade pip \
    && ./venv/bin/pip install -e . \
    && cd frontend \
    && npm ci \
    && npm run build \
    && mkdir -p /opt/hermes-hudui/backend/static \
    && rm -rf /opt/hermes-hudui/backend/static/assets \
    && cp -R dist/. /opt/hermes-hudui/backend/static/ \
    && chown -R hermes:hermes /opt/hermes-hudui


# 添加 hudui 为 s6-overlay 服务（与现有 dashboard 服务同级）
# 这样 s6 统一管理进程生命周期：dashboard、hudui、main-hermes 三个服务并行运行
# 不使用 entrypoint 脚本手动起进程，与基础镜像的 s6 架构保持一致
#
# 服务目录结构：
#   /etc/s6-overlay/s6-rc.d/hudui/type          -> longrun
#   /etc/s6-overlay/s6-rc.d/hudui/run           -> 启动脚本
#   /etc/s6-overlay/s6-rc.d/hudui/finish        -> 退出处理
#   /etc/s6-overlay/s6-rc.d/hudui/dependencies.d/base  -> 依赖（空文件，与 dashboard 同级）
#
# 将 hudui 加入 user bundle（与 dashboard、main-hermes 并列）
RUN mkdir -p /etc/s6-overlay/s6-rc.d/hudui/dependencies.d

# hudui 服务类型：longrun（长期运行的服务）
RUN echo "longrun" > /etc/s6-overlay/s6-rc.d/hudui/type

# hudui 启动脚本
# - 以 hermes 用户运行（s6-setuidgid）
# - 激活 hudui 自己的 venv
# - HERMES_HOME 指向 /opt/data（hermes 数据目录）
# - --host 0.0.0.0 --unsafe-allow-remote 绑定到所有网卡（容器环境需要外部访问）
# - 默认端口 3001
COPY hudui-run /etc/s6-overlay/s6-rc.d/hudui/run
RUN chmod +x /etc/s6-overlay/s6-rc.d/hudui/run

# hudui finish 脚本（与 dashboard/finish 类似，非 125 退出码允许 s6 重启）
COPY hudui-finish /etc/s6-overlay/s6-rc.d/hudui/finish
RUN chmod +x /etc/s6-overlay/s6-rc.d/hudui/finish

# 依赖 base（与 dashboard、main-hermes 同级，空文件）
RUN touch /etc/s6-overlay/s6-rc.d/hudui/dependencies.d/base

# 将 hudui 加入 user bundle（与 dashboard、main-hermes 并列）
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/hudui


# hudui 默认端口
EXPOSE 3001

# hermes dashboard 端口（继承自基础镜像，由 s6 dashboard 服务监听）
EXPOSE 9119


# 入口点：使用基础镜像的 /init（s6-overlay）
# s6-overlay 会自动启动 user bundle 中的所有服务（dashboard、main-hermes、hudui）
# Docker CMD（如 hermes chat）作为 s6 的 main program 运行
# 无需自定义 entrypoint 脚本
ENTRYPOINT ["/init"]
CMD ["hermes"]
