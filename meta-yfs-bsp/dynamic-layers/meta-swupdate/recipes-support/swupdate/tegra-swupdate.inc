inherit l4t_bsp
inherit l4t_version

TEGRA_SWUPDATE_BOOTLOADER_INSTALL_ONLY_IF_DIFFERENT ?= "false"
TEGRA_SWUPDATE_BOOTLOADER_VERSION ?= "${L4T_VERSION}"
TEGRA_SWUPDATE_CAPSULE_INSTALL_PATH ?= "/boot/efi/EFI/UpdateCapsule/TEGRA_BL.Cap"
TEGRA_SWUPDATE_LAST_CAPSULE_UPDATE_COMPLETE_SLOT_MARKER ?= ""
# Enable conditional bootloader installation
TEGRA_SWUPDATE_BOOTLOADER_INSTALL_ONLY_IF_DIFFERENT = "true"

# Define the persistent path prefix for slot boot markers
# Note: Ensure /var/lib/swupdate resides on a persistent read-write partition/overlay
TEGRA_SWUPDATE_LAST_CAPSULE_UPDATE_COMPLETE_SLOT_MARKER = "/var/lib/swupdate/capsule-complete-slot-"