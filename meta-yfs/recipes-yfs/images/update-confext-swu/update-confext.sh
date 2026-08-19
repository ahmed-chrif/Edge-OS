#!/bin/sh
set -e

TARGET_DIR="/var/lib/confexts"
NEW_IMAGE="my-new-app-v2.confext.raw"

echo "Stopping application service..."
systemctl stop my-new-app.service || true

echo "Unmerging active confext overlays..."
systemd-confext unmerge || true

# Safely delete older my-new-app images EXCEPT the newly unpacked version
find "$TARGET_DIR" -maxdepth 1 -type f -name "my-new-app*.confext.raw" ! -name "$NEW_IMAGE" -exec rm -vf {} +

echo "Refreshing systemd confext overlays..."
systemd-confext --mutable=ephemeral refresh

echo "Restarting application service..."
systemctl daemon-reload
systemctl restart my-new-app.service || true

exit 0