
FROM python:3

ARG PIP_ARGS

RUN pip install --no-cache-dir $PIP_ARGS \
    && rm -Rf /var/log/* \
    && echo '结束'