#!/usr/bin/env sh

set -e

CONFIG_FILE="/etc/proxysql/proxysql.cnf"

if [ ! -f "/etc/proxysql/proxysql.cnf" ]; then
    cp /etc/proxysql/proxysql.cnf.default "$CONFIG_FILE"

    
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

    if [ -f "$CONFIG_FILE" ]; then
        sed -i "s|^\(\s*${conf_key}\s*=\s*\).*|\1${val}|" "$CONFIG_FILE"
    fi
done

fi


exec "$@"
