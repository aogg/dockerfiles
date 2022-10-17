FROM docker.io/adoptopenjdk/openjdk8:latest

ENV AUTO_RUN_DIR ./mycat2
ENV DEPENDENCE_FILE mycat2-1.22-release-jar-with-dependencies.jar
ENV TEMPLATE_FILE mycat2-install-template-1.21.zip


RUN buildDeps='procps wget unzip' \
    && apt-get update \
    && apt-get install -y $buildDeps \
    && apt-get clean \
    && wget -P  $AUTO_RUN_DIR/ http://dl.mycat.org.cn/2.0/1.22-release/$DEPENDENCE_FILE \
    &&  wget -P  $AUTO_RUN_DIR/ http://dl.mycat.org.cn/2.0/install-template/$TEMPLATE_FILE  \
    && cd $AUTO_RUN_DIR/ \
    && unzip $TEMPLATE_FILE \
    && ls -al . \
    && mv  $DEPENDENCE_FILE mycat/lib/ \
    && chmod +x  mycat/bin/* \
    && chmod 755  mycat/lib/* \
    && mv mycat /usr/local
    
#copy mycat /usr/local/mycat/
VOLUME /usr/local/mycat/conf
VOLUME /usr/local/mycat/logs

EXPOSE 8066 1984
CMD ["/usr/local/mycat/bin/mycat", "console"]
