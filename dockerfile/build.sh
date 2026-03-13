#!/bin/bash
set -e

GITHUB_NAME=$1
DOCKERFILE_PATH=${3:-"./Dockerfile"}
IMAGE_NAME=${2:-"adockero/$1"}

echo "Building Docker image for $GITHUB_NAME"
echo "Dockerfile path: $DOCKERFILE_PATH"
echo "Image name: $IMAGE_NAME"

# Clone repository
if [[ "$GITHUB_NAME" == http://* ]] || [[ "$GITHUB_NAME" == https://* ]]; then
    git clone $GITHUB_NAME project
else
    git clone https://github.com/aogg/$GITHUB_NAME project
fi
cd project
rm -Rf ./.git

# Build image
echo "开始构建--------------------------------------------------------------------"
docker build -f $DOCKERFILE_PATH -t $IMAGE_NAME .
echo "构建完成--------------------------------------------------------------------"

# Push to registry
docker push $IMAGE_NAME

