SUMMARY = "EdgeOS base immutable image"
LICENSE = "MIT"
inherit core-image image_types_tegra read-only-fs
RM_WORK_EXCLUDE += "yfs-image-base"

IMAGE_INSTALL:append = " \
    persistent-mount \
    edgeos-extensions \
"
# Added edgeos-app-sysext and edgeos-app-confext-image dependencies
do_rootfs[depends] += " \
    edgeos-hello-sysext:do_image_complete \
    edgeos-app-sysext:do_image_complete \
    edgeos-app-confext-image:do_image_complete \
    htop-confext-image:do_image_complete \
"

seed_factory_extensions() {
    install -d ${IMAGE_ROOTFS}/usr/share/factory-extensions
    
    # Copy all sysext images
    cp -L ${DEPLOY_DIR_IMAGE}/edgeos-hello-sysext-${MACHINE}.sysext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    cp -L ${DEPLOY_DIR_IMAGE}/edgeos-app-sysext-${MACHINE}.sysext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    
    # Copy all confext images
    cp -L ${DEPLOY_DIR_IMAGE}/htop-confext-image-${MACHINE}.confext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    cp -L ${DEPLOY_DIR_IMAGE}/edgeos-app-confext-image-${MACHINE}.confext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    
    chmod 0644 ${IMAGE_ROOTFS}/usr/share/factory-extensions/*.raw
}

setup_ssh_symlinks() {
    mkdir -p ${IMAGE_ROOTFS}/var/lib/ssh
    mkdir -p ${IMAGE_ROOTFS}/etc/ssh
    
    rm -f ${IMAGE_ROOTFS}/etc/ssh/ssh_host_*
    ln -sf ../../var/lib/ssh/ssh_host_rsa_key ${IMAGE_ROOTFS}/etc/ssh/ssh_host_rsa_key
    ln -sf ../../var/lib/ssh/ssh_host_ecdsa_key ${IMAGE_ROOTFS}/etc/ssh/ssh_host_ecdsa_key
    ln -sf ../../var/lib/ssh/ssh_host_ed25519_key ${IMAGE_ROOTFS}/etc/ssh/ssh_host_ed25519_key
}
# Create a symlink to volatile/writable storage during rootfs assembly
setup_readonly_machine_id() {
    rm -f ${IMAGE_ROOTFS}/etc/machine-id
    ln -sf /var/machine-id ${IMAGE_ROOTFS}/etc/machine-id
}

ROOTFS_POSTPROCESS_COMMAND += "setup_readonly_machine_id; "
ROOTFS_POSTPROCESS_COMMAND += "seed_factory_extensions; setup_ssh_symlinks; "