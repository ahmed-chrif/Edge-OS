SUMMARY = "EdgeOS base immutable image"
LICENSE = "MIT"
inherit core-image image_types_tegra read-only-fs

IMAGE_INSTALL:append = " persistent-mount"

# 1. Force BOTH the sysext and confext images to build BEFORE this base rootfs is created
do_rootfs[depends] += " \
    edgeos-hello-sysext:do_image_complete \
    htop-confext-image:do_image_complete \
"

# 2. Define a function to copy the raw sysext and confext images into a staging directory
seed_factory_extensions() {
    install -d ${IMAGE_ROOTFS}/usr/share/factory-extensions
    
    # Target the unversioned symlinks explicitly, and resolve them to real files using cp -L
    cp -L ${DEPLOY_DIR_IMAGE}/edgeos-hello-sysext-${MACHINE}.sysext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    cp -L ${DEPLOY_DIR_IMAGE}/htop-confext-image-${MACHINE}.confext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    
    chmod 0644 ${IMAGE_ROOTFS}/usr/share/factory-extensions/*.raw
}

# 3. Append the function to the rootfs generation process
ROOTFS_POSTPROCESS_COMMAND += "seed_factory_extensions; "