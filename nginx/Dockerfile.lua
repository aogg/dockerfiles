FROM nginx

RUN apt-get update \
      && apt-get install -y --no-install-recommends libnginx-mod-http-lua/bionic-updates \
      && rm -rf /var/lib/apt/lists/* 
