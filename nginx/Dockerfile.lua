FROM nginx

RUN apt-get update \
      && apt-get install -y --no-install-recommends libnginx-mod-http-lua \
      && rm -rf /var/lib/apt/lists/* 
