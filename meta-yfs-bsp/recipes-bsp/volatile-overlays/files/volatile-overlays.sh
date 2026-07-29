#!/bin/sh
# Use /run as the backing store since systemd mounts it as tmpfs before sysinit.target
OVERLAY_BASE="/run/volatile-overlays"
mkdir -p "$OVERLAY_BASE"

# Define the read-only directories you want to make dynamically writable
TARGETS="/usr /etc /opt /home"

for TARGET in $TARGETS; do
    if [ -d "$TARGET" ]; then
        UPPER="${OVERLAY_BASE}${TARGET}_upper"
        WORK="${OVERLAY_BASE}${TARGET}_work"
        
        mkdir -p "$UPPER" "$WORK"
        
        # Mount the writable RAM overlay on top of the existing directory
        mount -t overlay overlay -o lowerdir="$TARGET",upperdir="$UPPER",workdir="$WORK" "$TARGET"
    fi
done