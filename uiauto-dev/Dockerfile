FROM python:3.8

RUN pip3 install --no-cache-dir -U uiautodev \
    && rm -Rf /var/log/*


ENTRYPOINT [ "uiauto.dev"]
CMD [ "server", "--host", "0.0.0.0" ]