#!/bin/sh
# Do NOT set 'set -e' globally, as we need custom error catching for rollback

TARGET_DIR="/var/lib/extensions"
NEW_IMAGE="my-new-app-v2.sysext.raw"
SERVICE_NAME="my-new-app.service"

# 1. Identify the existing active extension image (e.g., v1.0) before doing anything
OLD_IMAGE=$(find "$TARGET_DIR" -maxdepth 1 -type f -name "my-new-app*.sysext.raw" ! -name "$NEW_IMAGE" | head -n 1)

# Function to restore v1.0 if anything breaks during installation
rollback() {
    echo "CRITICAL: Update failed! Rolling back to previous version..."
    systemctl stop "$SERVICE_NAME" || true
    systemd-sysext unmerge || true
    
    # Remove the broken new image
    rm -f "$TARGET_DIR/$NEW_IMAGE"
    
    # Re-merge the old image
    systemd-sysext --mutable=ephemeral refresh
    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME" || true
    
    echo "Rollback complete. The app remains on the old version."
    exit 1
}

echo "Step 1: Stopping the current application..."
systemctl stop "$SERVICE_NAME" || rollback

echo "Step 2: Unmerging systemd-sysext..."
systemd-sysext unmerge || rollback

echo "Step 3: Refreshing systemd-sysext to load the NEW_IMAGE..."
systemd-sysext --mutable=ephemeral refresh || rollback

echo "Step 4: Reloading systemd and starting $SERVICE_NAME..."
systemctl daemon-reload
if ! systemctl restart "$SERVICE_NAME"; then
    echo "ERROR: Service failed to start on new version!"
    rollback
fi

# Optional: Add a simple health check here (e.g., check if process stays alive or responds)
sleep 2
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "ERROR: Service crashed shortly after startup!"
    rollback
fi

echo "Step 5: Success! Cleaning up the OLD_IMAGE..."
if [ -n "$OLD_IMAGE" ] && [ -f "$OLD_IMAGE" ]; then
    rm -vf "$OLD_IMAGE"
fi

echo "Update successfully completed!"
exit 0