

# apisix相关容器

![最近镜像构建状态](https://github.com/aogg/dockerfiles/workflows/apisix-%E6%9E%84%E5%BB%BA%E5%92%8C%E6%8F%90%E4%BA%A4docker/badge.svg)

1、latest对应master分支（2版本），1.5分支版本（不可用）官方应该是没有独立的dashboard的
2、整体dashboard架构，apisix-dashboard的前端dashboard和后端manager


# 当前项目核心

1、apisix-dashboard登录用户可控制账号名和密码，没有view用户
2、非固定ip的demo。
3、全面的`docker env`，可通过`docker image inspect adockero/apisix-dashboard:manager`查看
4、不需要本地构建容器，直接使用[hub.docker.com](https://hub.docker.com/repository/docker/adockero/apisix-dashboard)提供的容器
