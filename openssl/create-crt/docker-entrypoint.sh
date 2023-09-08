#!/usr/bin/env bash

rm -Rf /openssl;
mkdir -p /openssl;
cd /openssl;

openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=New York/L=New York/O=Example Company/CN=example.com"
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

ls -al 