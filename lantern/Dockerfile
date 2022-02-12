FROM ubuntu

ARG VERSION=6.9.11

# since https://github.com/xiaoqingfengATGH/lantern
# lastest lantern version: 6.7.1
WORKDIR /root
RUN apt-get update  && \
         apt-get -y install wget libappindicator3-1 libpcap0.8:amd64 && \
         wget -O lantern.deb https://raw.githubusercontent.com/getlantern/lantern-binaries/main/lantern-installer-64-bit.deb?ver=${VERSION} && \
         wget -O settings.yaml https://raw.githubusercontent.com/xiaoqingfengATGH/lantern/master/settings.yaml?ver=${VERSION} && \
         dpkg -i lantern.deb && \
         rm -rf lantern.deb && \
         apt-get -f install && \
         apt-get clean && \
         rm -rf /var/cache/apt/* /var/lib/apt/lists/* && \
         mkdir /root/.lantern && \
         mv settings.yaml /root/.lantern/settings.yaml

EXPOSE 3128/tcp 8080/tcp 3129/tcp

ENTRYPOINT ["/usr/bin/lantern", "--configdir=/root/.lantern", "--headless=true"]