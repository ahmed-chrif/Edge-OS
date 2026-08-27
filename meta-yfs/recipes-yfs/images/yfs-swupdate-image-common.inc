SUMMARY = "YFS SWUpdate update image"
DESCRIPTION = "A swupdate payload image for YFS Distro"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "\
    file://sw-description \
"

inherit swupdate image_types_tegra

require dynamic-layers/meta-swupdate/recipes-support/swupdate/tegra-swupdate.inc

ROOTFS_DEVICE_PATH ?= "/dev/disk/by-partlabel"

SWUPDATE_CORE_IMAGE_NAME ?= "${@d.getVar('BPN').replace('-swupdate', '')}"

# CHANGED: Expect a SquashFS artifact instead of a tarball
ROOTFS_FILENAME ?= "${SWUPDATE_CORE_IMAGE_NAME}-${MACHINE}.rootfs.squashfs"

IMAGE_DEPENDS = "${SWUPDATE_CORE_IMAGE_NAME}"

SWUPDATE_IMAGES = "${ROOTFS_FILENAME} tegra-bl.cap tegra-swupdate-script.lua"

do_swuimage[depends] += "tegra-uefi-capsules:do_deploy"
do_swuimage[depends] += "tegra-swupdate-script:do_deploy"

do_swuimage:append() {
    os.symlink(d.getVar("IMAGE_NAME") + ".swu", d.getVar("SWUPDATE_CORE_IMAGE_NAME") + "-" + d.getVar("MACHINE") + ".swu")
}