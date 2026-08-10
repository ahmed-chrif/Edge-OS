#
# Backported from upstream OpenEmbedded-Core.
#
# Introduced after Yocto Scarthgap.
# Only minimal compatibility fixes should be applied.
#
#
# Copyright OpenEmbedded Contributors
#
# SPDX-License-Identifier: MIT
#

# System extension images may – dynamically at runtime — extend the
# /usr/ and /opt/ directory hierarchies with additional files. This is
# particularly useful on immutable system images where a /usr/ and/or
# /opt/ hierarchy residing on a read-only file system shall be
# extended temporarily at runtime without making any persistent
# modifications.

## Example usage:
#
# SUMMARY = "Example system extension image"
# LICENSE = "MIT"
#
# inherit discoverable-disk-image sysext-image
#
# IMAGE_FEATURES = ""
# IMAGE_LINGUAS = ""
# IMAGE_INSTALL = "gdb"
#
# The resulting image can be placed into one of systemd-sysext's search
# directories and merged at runtime.
#
# NOTE:
# PACKAGECONFIG:pn-systemd must contain "sysext"

inherit image

# Include ".sysext" in the deployed image filename and symlink
IMAGE_NAME = "${IMAGE_BASENAME}${IMAGE_MACHINE_SUFFIX}${IMAGE_VERSION_SUFFIX}.sysext"
IMAGE_LINK_NAME = "${IMAGE_BASENAME}${IMAGE_MACHINE_SUFFIX}.sysext"
EXTENSION_NAME = "${IMAGE_LINK_NAME}.${IMAGE_FSTYPES}"

# Base extension identification fields
EXTENSION_ID_FIELD ?= "${DISTRO}"
EXTENSION_VERSION_FIELD ?= "${DISTRO_VERSION}"

sysext_image_add_version_identifier_file() {

    echo 'ID=${EXTENSION_ID_FIELD}' > ${WORKDIR}/extension-release.base

    # os-release.bb sanitises VERSION_ID, do the same here
    echo 'VERSION_ID=${EXTENSION_VERSION_FIELD}' \
        | sed 's,+,-,g;s, ,_,g' \
        >> ${WORKDIR}/extension-release.base

    # Tell systemd to reload after merge
    echo 'EXTENSION_RELOAD_MANAGER=1' \
        >> ${WORKDIR}/extension-release.base

    install -d \
        ${IMAGE_ROOTFS}${nonarch_libdir}/extension-release.d

    install -m 0644 \
        ${WORKDIR}/extension-release.base \
        ${IMAGE_ROOTFS}${nonarch_libdir}/extension-release.d/extension-release.${EXTENSION_NAME}

    # Allow the image file to be renamed while remaining mergeable
    setfattr \
        -n user.extension-release.strict \
        -v false \
        ${IMAGE_ROOTFS}${nonarch_libdir}/extension-release.d/extension-release.${EXTENSION_NAME}
}

ROOTFS_POSTPROCESS_COMMAND += "sysext_image_add_version_identifier_file;"

# systemd-sysext rejects images containing /usr/lib/os-release
PACKAGE_EXCLUDE += "os-release"
# Add to sysext-image.bbclass or edgeos-hello-sysext.bb

IMAGE_CMD:raw () {
    mksquashfs ${IMAGE_ROOTFS} ${IMGDEPLOYDIR}/${IMAGE_NAME}.raw -noappend ${EXTRA_IMAGECMD}
}

# Ensure native squashfs tools are built before running the raw image command
do_image_raw[depends] += "squashfs-tools-native:do_populate_sysroot"