FROM debian:7

RUN apt-get update \
    && apt-get install -y curlftpfs

RUN echo "user_allow_other" >> /etc/fuse.conf \
    && mkdir -p /run/docker/plugins /mnt/state /mnt/volumes

# CMD curlftpfs -o user=username:password ftp.example.com /mnt/my_ftp_dir
