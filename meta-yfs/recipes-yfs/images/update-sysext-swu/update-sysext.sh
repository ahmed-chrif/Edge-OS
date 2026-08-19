#!/bin/sh
set -e

TARGET_DIR="/var/lib/extensions"
NEW_IMAGE="my-new-app-v2.sysext.raw"

echo "Stopping application service..."
systemctl stop my-new-app.service || true

echo "Unmerging active sysext overlays..."
systemd-sysext unmerge || true

# Safely delete older my-new-app images EXCEPT the newly unpacked version
find "$TARGET_DIR" -maxdepth 1 -type f -name "my-new-app*.sysext.raw" ! -name "$NEW_IMAGE" -exec rm -vf {} +

echo "Refreshing systemd sysext overlays..."
systemd-sysext --mutable=ephemeral refresh

echo "Restarting application service..."
systemctl daemon-reload
systemctl restart my-new-app.service || true

exit 0