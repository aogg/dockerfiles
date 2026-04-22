FROM proxysql/proxysql:3-debian

COPY proxysql.cnf /etc/proxysql/proxysql.cnf.default
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/var/lib/proxysql"]

EXPOSE 6032 6033 6070

ENTRYPOINT ["/entrypoint.sh"]
CMD ["proxysql", "-f", "--config", "/etc/proxysql/proxysql.cnf"]
