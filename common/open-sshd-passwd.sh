#!/usr/bin/env sh 

# SSHD
# generate fresh rsa key
if [ ! -f /etc/ssh/ssh_host_rsa_key ];then
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
fi
# generate fresh dsa key
if [ ! -f /etc/ssh/ssh_host_dsa_key ];then
ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
fi
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

`which sshd` -p ${SSHD_PORT} "$@"