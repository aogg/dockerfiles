
FROM adockero/selenium-chrome-pip:kasmweb-1.13.0-selenium


# docker rm -f debug-selenium-www.openfrp.net;\
# docker run -t --rm --name debug-selenium-www.openfrp.net --network common-all -u root --entrypoint /bin/bash \
# --shm-size=512m \
# --add-host challenges.cloudflare.com:162.159.9.55 \
# -e URL="https://nowsecure.nl/" \
# -e APP_ARGS="--start-maximized --remote-debugging-address=0.0.0.0 --remote-debugging-port=1234 https://nowsecure.nl/" \
# -p 6901:6901 \
# -e VNC_PW=123 \
# -e FIND_ELEMENTS='*[@id="challenge-stage"]/div/label' \
# -v /data/docker/selenium/www.openfrp.net/:/data/docker/selenium/ \
# adockero/selenium-chrome-pip:kasmweb-1.13.0-selenium \
# -c '((/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait &); sleep 6 && python3 /data/docker/selenium/getCookie-origin-remote.py) 2>&1'

USER root

RUN mkdir -p /getCookie/ \
    && cd /getCookie \
    && chown -R kasm-user:kasm-user /getCookie \
    && wget https://raw.githubusercontent.com/requireCool/stealth.min.js/main/stealth.min.js

WORKDIR /getCookie

COPY --chown=kasm-user:kasm-user docker-cmd.sh /docker-cmd.sh


ENTRYPOINT [ "/usr/bin/bash" ]
CMD [ "/docker-cmd.sh" ]

# 截图存储目录
ENV DATA_DIR
# 获取哪个网站的cookie
ENV URL
# 需要点击进入的按钮xpath
ENV FIND_ELEMENTS_XPATH
# 如果存在cookie的key就直接跳出
ENV IF_COOKIE_KEY
# 保存cookie的值到文件
ENV COOKIE_FILE_PATH

# vnc密码--上层
# ENV VNC_PW

COPY --chown=kasm-user:kasm-user getCookie.py /getCookie/getCookie.py


USER kasm-user
