#!/bin/bash

# 1. Identify the device name based on the size (1.8T)
# This captures the name (e.g., sda1) of the partition matching that size
DEVICE_NAME=$(lsblk -no NAME,SIZE | grep "1.8T" | awk '{print $1}')

if [ -z "$DEVICE_NAME" ]; then
    echo "Error: 1.8T Drive not found."
    exit 1
fi

# 2. Define the full path
DEVICE_PATH="/dev/$DEVICE_NAME"
MOUNT_POINT="/mnt/homelab"
DOCKER_DIR="$HOME/server"

echo "Found drive at $DEVICE_PATH. Attempting to mount..."

# 3. Mount the drive if not already mounted
if ! findmnt -kn "$MOUNT_POINT" > /dev/null; then
    sudo mount "$DEVICE_PATH" "$MOUNT_POINT"
fi

# 4. Handle Docker containers
if [ -d "$DOCKER_DIR" ]; then
    cd "$DOCKER_DIR" || exit
    echo "Restarting Docker containers..."
    docker compose down && docker compose up -d
else
    echo "Error: Docker directory $DOCKER_DIR not found."
    exit 1
fi
