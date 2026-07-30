#!/bin/sh
OVERLAY_BASE="/run/volatile-overlays"
TARGETS="/usr /opt"

do_start() {
    mkdir -p "$OVERLAY_BASE"
    for TARGET in $TARGETS; do
        if [ -d "$TARGET" ]; then
            UPPER="${OVERLAY_BASE}${TARGET}_upper"
            WORK="${OVERLAY_BASE}${TARGET}_work"
            
            mkdir -p "$UPPER" "$WORK"
            
            # Avoid double-mounting if already mounted
            if ! mountpoint -q "$TARGET"; then
                mount -t overlay overlay -o lowerdir="$TARGET",upperdir="$UPPER",workdir="$WORK" "$TARGET"
                echo "Mounted volatile overlay on $TARGET"
            fi
        fi
    done
}

do_stop() {
    # Unmount in reverse order
    for TARGET in $TARGETS; do
        if mountpoint -q "$TARGET"; then
            echo "Unmounting volatile overlay from $TARGET"
            umount "$TARGET" || umount -l "$TARGET"
        fi
    done
    rm -rf "$OVERLAY_BASE"
}

case "$1" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac