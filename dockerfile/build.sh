#!/bin/bash
set -e

GITHUB_NAME=$1
DOCKERFILE_PATH=${3:"./Dockerfile"}
IMAGE_NAME=${2:-$1}

# Clone repository
git clone https://github.com/aogg/$GITHUB_NAME project
cd project

# Build image
docker build -f $DOCKERFILE_PATH -t $IMAGE_NAME .

# Push to registry
docker push $IMAGE_NAME

