#!/bin/sh
PART_DEV="/dev/nvme0n1p17"

# Wait for the device block to populate
for i in $(seq 1 10); do
    if [ -b "$PART_DEV" ]; then
        break
    fi
    sleep 0.5
done

if [ ! -b "$PART_DEV" ]; then
    echo "Error: persistent storage partition block device not found."
    exit 1
fi

# Verify if an ext4 signature exists, format if missing
if ! blkid "$PART_DEV" | grep -q 'TYPE="ext4"'; then
    echo "First-time setup: Formatting $PART_DEV as ext4..."
    mkfs.ext4 -F "$PART_DEV"
fi

# Mount the partition directly over /var
echo "Mounting persistent partition to /var..."
mount -t ext4 -o noatime "$PART_DEV" /var

# Ensure the required directory structure always exists on the mounted partition
echo "Ensuring systemd-sysext and system directory structure on /var..."
mkdir -p /var/lib/extensions
mkdir -p /var/lib/confexts
mkdir -p /var/etc

# Essential base system directories to prevent early-boot service crashes
mkdir -p /var/log
mkdir -p /var/tmp
mkdir -p /var/lib/systemd
chmod 1777 /var/tmp