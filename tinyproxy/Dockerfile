FROM dannydirect/tinyproxy

# 不行
# RUN ln -s /proc/1/fd/2 /var/log/tinyproxy/tinyproxy.log

# RUN touch /var/log/tinyproxy/tinyproxy.log && \
#     chmod 777 /var/log/tinyproxy/tinyproxy.log


# 删除才能输出到docker日志
RUN sed -i '/LogFile/d' /etc/tinyproxy/tinyproxy.conf \
    && touch /var/log/tinyproxy/tinyproxy.log && \
    chmod 777 /var/log/tinyproxy/tinyproxy.log



CMD ["ANY"]