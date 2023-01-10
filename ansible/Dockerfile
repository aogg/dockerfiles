
ARG BASE_FORM=2.13-tools

FROM cytopia/ansible:$BASE_FORM

ARG APK_ADD

# @see https://github.com/danielguerra69/docker-sshd/blob/master/Dockerfile
RUN apk add --no-cache $APK_ADD;