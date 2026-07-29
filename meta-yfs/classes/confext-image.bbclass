#
# Class for systemd-confext images
#

inherit image

# Include ".confext" in the deployed image filename and symlink
IMAGE_NAME = "${IMAGE_BASENAME}${IMAGE_MACHINE_SUFFIX}${IMAGE_VERSION_SUFFIX}.confext"
IMAGE_LINK_NAME = "${IMAGE_BASENAME}${IMAGE_MACHINE_SUFFIX}.confext"
EXTENSION_NAME = "${IMAGE_LINK_NAME}.${IMAGE_FSTYPES}"

# Base extension identification fields
EXTENSION_ID_FIELD ?= "${DISTRO}"
EXTENSION_VERSION_FIELD ?= "${DISTRO_VERSION}"

confext_image_add_version_identifier_file() {
    echo 'ID=${EXTENSION_ID_FIELD}' > ${WORKDIR}/extension-release.base

    # os-release.bb sanitises VERSION_ID, do the same here
    echo 'VERSION_ID=${EXTENSION_VERSION_FIELD}' \
        | sed 's,+,-,g;s, ,_,g' \
        >> ${WORKDIR}/extension-release.base

    # Tell systemd to reload after merge
    echo 'EXTENSION_RELOAD_MANAGER=1' \
        >> ${WORKDIR}/extension-release.base

    # IMPORTANT: confext expects the release file in /etc/extension-release.d/
    install -d \
        ${IMAGE_ROOTFS}${sysconfdir}/extension-release.d

    install -m 0644 \
        ${WORKDIR}/extension-release.base \
        ${IMAGE_ROOTFS}${sysconfdir}/extension-release.d/extension-release.${EXTENSION_NAME}

    # Allow the image file to be renamed while remaining mergeable
    setfattr \
        -n user.extension-release.strict \
        -v false \
        ${IMAGE_ROOTFS}${sysconfdir}/extension-release.d/extension-release.${EXTENSION_NAME}
}

ROOTFS_POSTPROCESS_COMMAND += "confext_image_add_version_identifier_file;"

IMAGE_CMD:raw () {
    mksquashfs ${IMAGE_ROOTFS} ${IMGDEPLOYDIR}/${IMAGE_NAME}.raw -noappend ${EXTRA_IMAGECMD}
}

# Ensure native squashfs tools are built before running the raw image command
do_image_raw[depends] += "squashfs-tools-native:do_populate_sysroot"