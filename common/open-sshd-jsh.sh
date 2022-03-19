#!/usr/bin/env sh 



if [ -n "$SSHD_OPEN_JSH" ];then
    echo '开启jsh';
    echo 'KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1' >> /etc/ssh/sshd_config
    echo 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com,hmac-md5,hmac-sha1,hmac-sha1-96,hmac-md5-96' >> /etc/ssh/sshd_config
fi
