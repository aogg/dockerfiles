#!/usr/bin/env sh

set -e

CONFIG_FILE="/etc/proxysql/proxysql.cnf"
CONFIG_DEFAULT="/etc/proxysql/proxysql.cnf.default"
LOG_DIR="/var/log/proxysql"
LOG_FILE="${LOG_DIR}/proxysql_events.log"

if [ ! -f "$CONFIG_FILE" ]; then

    cp "$CONFIG_DEFAULT" "$CONFIG_FILE"

    for env in $(printenv | sort); do
        key=$(echo "$env" | cut -d= -f1)
        val=$(echo "$env" | cut -d= -f2-)

        if ! echo "$key" | grep -q "^PROXY_"; then
            continue
        fi

        case "$key" in
            PROXY_MYSQL_HOST)       conf_key="address" ;;
            PROXY_MYSQL_PORT)       conf_key="port" ;;
            PROXY_MYSQL_USERNAME)   conf_key="username" ;;
            PROXY_MYSQL_PASSWORD)   conf_key="password" ;;
            PROXY_MONITOR_USERNAME) conf_key="monitor_username" ;;
            PROXY_MONITOR_PASSWORD) conf_key="monitor_password" ;;
            PROXY_WRITER_HOSTGROUP) conf_key="hostgroup" ;;
            PROXY_SERVER_VERSION)   conf_key="server_version" ;;
            *) continue ;;
        esac

        sed -i "s|^\(\s*${conf_key}\s*=\s*\).*|\1${val}|" "$CONFIG_FILE"
    done

    for env in $(printenv | sort); do
        key=$(echo "$env" | cut -d= -f1)
        val=$(echo "$env" | cut -d= -f2-)

        if ! echo "$key" | grep -q "^ENV_"; then
            continue
        fi

        key="${key#ENV_}"

        if echo "$key" | grep -q "__"; then
            conf_key=$(echo "$key" | cut -d__ -f2- | tr '[:upper:]' '[:lower:]')
        else
            conf_key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        fi

        sed -i "s|^\(\s*${conf_key}\s*=\s*\).*|\1${val}|" "$CONFIG_FILE"
    done

fi

rotate_logs() {
    while true; do
        now=$(date +%s)
        midnight=$(date -d "tomorrow 00:00:00" +%s)
        sleep $((midnight - now))

        if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
            DATE=$(date -d "yesterday" +%Y-%m-%d)
            cp "$LOG_FILE" "${LOG_DIR}/proxysql_events_${DATE}.log"
            > "$LOG_FILE"
            find "$LOG_DIR" -name "proxysql_events_*.log" -mtime +7 -exec gzip {} \;
        fi
    done
}

mkdir -p "$LOG_DIR"
rotate_logs &

exec "$@"
