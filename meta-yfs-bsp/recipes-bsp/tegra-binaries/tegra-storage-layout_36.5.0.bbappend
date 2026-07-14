# Match your actual directory structure ("files")
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:tegra234 = " \
    file://flash_l4t_t234_nvme_rootfs_ab.xml \
"

PARTITION_FILE_EXTERNAL:tegra234 = "${WORKDIR}/flash_l4t_t234_nvme_rootfs_ab.xml"