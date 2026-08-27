DESCRIPTION = "SWUpdate image for systemd confext update"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit swupdate

SRC_URI = " \
    file://sw-description \
    file://update-confext.sh \
"

SWUPDATE_IMAGES = "my-new-app-confext"
SWUPDATE_IMAGES_FSTYPES[my-new-app-confext] = ".confext.raw"
SWUPDATE_IMAGES_NOAPPEND_MACHINE[my-new-app-confext] = "0"

do_swuimage[depends] += "my-new-app-confext:do_image_complete"