#!/bin/bash

# Paths
SRC_DIR="/tmp2/rabhunter/lab3"
DEST_DIR="/tmp2/$(whoami)/lab3"

# Ensure destination directory exists
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

# Files to check
FILES=("lab3.qcow2" "lab3-1.qcow2" "lab3-2.qcow2" "lab3_ovmf.4m.fd")

# Check and copy missing files
for file in "${FILES[@]}"; do
    if [ ! -f "$DEST_DIR/$file" ]; then
        echo "Copying $file to $DEST_DIR"
        cp "$SRC_DIR/$file" "$DEST_DIR/"
    fi
done

# Generate random ports
VNC_PORT=$((RANDOM % 100 + 1))   # Random VNC display number (0-99)
SSH_PORT=$((RANDOM % 64512 + 1024)) # Random SSH port (1024-65535)

# Ensure SSH port is not in use
while ss -tuln | grep -q ":$SSH_PORT"; do
    SSH_PORT=$((RANDOM % 64512 + 1024))
done

echo "Using VNC display :$VNC_PORT (Port $((5900 + VNC_PORT)))"
echo "Using SSH port $SSH_PORT"

# Run QEMU
qemu-system-x86_64 \
    -smp 2 \
    -m 8G \
    -drive file=$DEST_DIR/lab3.qcow2,format=qcow2 \
    -vnc :$VNC_PORT,password=on \
    -monitor stdio \
    -enable-kvm \
    -nic user,hostfwd=tcp::$SSH_PORT-:22 \
    -drive if=pflash,format=raw,file=$DEST_DIR/lab3_ovmf.4m.fd \
    -drive file=$DEST_DIR/lab3-1.qcow2,format=qcow2 \
    -drive file=$DEST_DIR/lab3-2.qcow2,format=qcow2