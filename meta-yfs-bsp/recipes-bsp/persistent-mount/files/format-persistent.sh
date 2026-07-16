#!/bin/sh
PART_DEV="/dev/nvme0n1p17"
# Wait for the device block to populate
for i in $(seq 1 10); do
    if [ -b "$PART_DEV" ]; then
        break
    fi
    sleep 1
done

if [ ! -b "$PART_DEV" ]; then
    echo "Error: persistent storage partition block device not found."
    exit 1
fi

# Verify if an ext4 signature exists, format if missing
if ! blkid "$PART_DEV" | grep -q "type=\"ext4\""; then
    echo "Formatting $PART_DEV as ext4..."
    mkfs.ext4 -F "$PART_DEV"
fi

# Ensure mount target exists and mount it
mkdir -p /mnt/persistent
mount -t ext4 -o noatime "$PART_DEV" /mnt/persistent