FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://flash_l4t_t234_nvme_rootfs_ab.xml"


# Point directly to the file inside your meta-layer
PARTITION_FILE_EXTERNAL = "${TOPDIR}/../meta-yfs-bsp/recipes-bsp/tegra-binaries/files/flash_l4t_t234_nvme_rootfs_ab.xml"