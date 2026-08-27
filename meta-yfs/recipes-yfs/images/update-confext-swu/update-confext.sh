#!/bin/sh
# Do NOT set 'set -e' globally, as we need custom error catching for rollback

TARGET_DIR="/var/lib/confexts"
NEW_IMAGE_NAME="my-new-app-v2.confext.raw"
NEW_IMAGE="$TARGET_DIR/$NEW_IMAGE_NAME"
SERVICE_NAME="my-new-app.service"

echo "=== Starting EdgeOS Atomic Confext Update ==="

# 1. Identify the existing active configuration image before doing anything
OLD_IMAGE=$(find "$TARGET_DIR" -maxdepth 1 -type f -name "my-new-app*.confext.raw" ! -name "$NEW_IMAGE_NAME" | head -n 1)

# Function to restore previous configuration if anything breaks
rollback() {
    echo "CRITICAL: Confext update failed! Initiating rollback..."
    
    systemctl stop "$SERVICE_NAME" || true
    systemd-confext unmerge || true
    
    # Remove the broken new confext image
    rm -f "$NEW_IMAGE"
    
    # Re-merge the old image and restart service
    systemd-confext --mutable=ephemeral refresh || true
    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME" || true
    
    echo "Rollback complete. Restored previous configuration state."
    exit 1
}

echo "Step 1: Stopping $SERVICE_NAME..."
systemctl stop "$SERVICE_NAME" || rollback

echo "Step 2: Unmerging active configuration overlays..."
systemd-confext unmerge || rollback

echo "Step 3: Refreshing systemd-confext to load NEW_IMAGE..."
systemd-confext --mutable=ephemeral refresh || rollback

echo "Step 4: Reloading systemd and restarting $SERVICE_NAME..."
systemctl daemon-reload
if ! systemctl restart "$SERVICE_NAME"; then
    echo "ERROR: Service failed to start on new configuration!"
    rollback
fi

# Step 5: Health Check
sleep 2
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "ERROR: Service crashed or failed shortly after startup!"
    rollback
fi

echo "Step 6: Success! Cleaning up OLD_IMAGE..."
if [ -n "$OLD_IMAGE" ] && [ -f "$OLD_IMAGE" ]; then
    rm -vf "$OLD_IMAGE"
fi

echo "=== Confext Update Successful ==="
exit 0