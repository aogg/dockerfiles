# Copyright 2019 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================
#
# THIS IS A GENERATED DOCKERFILE.
#
# This file was assembled from multiple pieces, whose use is documented
# throughout. Please refer to the TensorFlow dockerfiles documentation
# for more information.

# @see https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/cpu.Dockerfile
# @see https://github.com/lakshayg/tensorflow-build

ARG UBUNTU_VERSION=18.04

FROM ubuntu:${UBUNTU_VERSION} as base


# See http://bugs.python.org/issue19846
ENV LANG C.UTF-8

RUN apt-get update && apt install --no-install-recommends --no-install-suggests -y curl \
    python3 \
    python3-pip \
    # 删除
    && rm -rf /var/lib/apt/lists/*


# RUN apt-get update && apt-get install -y

RUN python3 -m pip --no-cache-dir install --upgrade \
    "pip<21.3" \
    setuptools

# Some TF tools expect a "python" binary
RUN ln -s $(which python3) /usr/local/bin/python

# Options:
#   tensorflow
#   tensorflow-gpu
#   tf-nightly
#   tf-nightly-gpu
# Set --build-arg TF_PACKAGE_VERSION=1.11.0rc0 to install a specific version.
# Installs the latest version by default.
ARG TF_PACKAGE=tensorflow
ARG TF_PACKAGE_VERSION=
ARG TF_BUILD_DOWNLOAD='https://github.com/lakshayg/tensorflow-build/releases/download/tf2.2.0-py3.7-ubuntu18.04/tensorflow-2.2.0-cp37-cp37m-linux_x86_64.whl'
RUN python3 -m pip install --no-cache-dir --upgrade ${TF_BUILD_DOWNLOAD} --user

COPY bashrc /etc/bash.bashrc