#!/usr/bin/env ash 

# SSHD
# generate fresh rsa key
ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
# generate fresh dsa key
ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
#prepare run dir
mkdir -p /var/run/sshd
# prepare config file for key based auth
sed -i "s/UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config
sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config
sed -i "s/\(#\s*\)*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i "s/\(#\s*\)PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/#AuthorizedKeysFile/AuthorizedKeysFile/g" /etc/ssh/sshd_config

if [ -n "$SSHD_PASSWORD" ];then
    echo '设置密码';
    echo root:${SSHD_PASSWORD}|chpasswd
fi

/usr/sbin/sshd -p ${SSHD_PORT}



if [ -f /usr/local/bin/dockerd-entrypoint.sh ];then
    if [ -z "$@" ];then
        /usr/local/bin/dockerd-entrypoint.sh
    else
        /usr/local/bin/dockerd-entrypoint.sh "$@"
    fi
else
    if [ -z "$@" ];then
        /usr/local/bin/docker-entrypoint.sh
    else
        /usr/local/bin/docker-entrypoint.sh "$@"
    fi
fi


