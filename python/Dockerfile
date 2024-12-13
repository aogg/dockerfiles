
FROM python:3-alpine

ARG PIP_ARGS

RUN pip install --no-cache-dir $PIP_ARGS \
    && rm -Rf /var/log/* \
    && echo '结束'