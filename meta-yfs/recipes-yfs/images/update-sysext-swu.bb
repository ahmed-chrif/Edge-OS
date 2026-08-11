DESCRIPTION = "SWUpdate image for systemd sysext update"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit swupdate

SRC_URI = " \
    file://sw-description \
    file://update-sysext.sh \
"

SWUPDATE_IMAGES = "my-new-sysext"
SWUPDATE_IMAGES_FSTYPES[my-new-sysext] = ".sysext.raw"
SWUPDATE_IMAGES_NOAPPEND_MACHINE[my-new-sysext] = "0"

do_swuimage[depends] += "my-new-sysext:do_image_complete"