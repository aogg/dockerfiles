FROM proxysql/proxysql:3-debian

RUN mkdir -p /var/log/proxysql

COPY proxysql.cnf /etc/proxysql/proxysql.cnf.default
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/var/lib/proxysql"]
VOLUME ["/var/log/proxysql"]

EXPOSE 6032 6033 6070

ENTRYPOINT ["/entrypoint.sh"]
CMD ["proxysql", "-f", "--config", "/etc/proxysql/proxysql.cnf"]
