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
IS_FIRST_BOOT=0
if ! blkid "$PART_DEV" | grep -q 'TYPE="ext4"'; then
    echo "First-time setup: Formatting $PART_DEV as ext4..."
    mkfs.ext4 -F "$PART_DEV"
    IS_FIRST_BOOT=1
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
# === UPDATED: Seed factory extensions into their respective runtime folders ===
if [ -d "/usr/share/factory-extensions" ]; then
    echo "Seeding factory sysext images to /var/lib/extensions..."
    cp -n /usr/share/factory-extensions/*.sysext.raw /var/lib/extensions/ 2>/dev/null || true

    echo "Seeding factory confext images to /var/lib/confexts..."
    cp -n /usr/share/factory-extensions/*.confext.raw /var/lib/confexts/ 2>/dev/null || true
    cp -n /usr/share/factory-extensions/*.confext.raw /var/lib/confext/ 2>/dev/null || true
fi