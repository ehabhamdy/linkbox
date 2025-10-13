#!/bin/bash

# Stop existing container if running
CONTAINER_NAME="linkbox-backend"

if [ $(docker ps -q -f name=$CONTAINER_NAME) ]; then
    echo "Stopping existing container..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

echo "Application stopped successfully"