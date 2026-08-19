SUMMARY = "EdgeOS base immutable image"
LICENSE = "MIT"
inherit core-image image_types_tegra read-only-fs extrausers
RM_WORK_EXCLUDE += "yfs-image-base"

IMAGE_INSTALL:append = " \
    openssh \
    openssh-sshd \
    openssh-sftp-server \
    persistent-mount \
    swupdate \
    swupdate-www \
    edgeos-extensions \ 
"
# Add to the top or middle of yfs-image-base.bb


# FIX 1: Properly use extrausers in the image recipe to create the user/group.
# We use :append to ensure we don't accidentally overwrite the root password 
# configuration you set in kas/include/configs/dev/debug.yml.
EXTRA_USERS_PARAMS:append = " \
    groupadd -r sshd; \
    useradd -r -g sshd -d /var/empty -s /sbin/nologin -c 'Privilege-separated SSH' sshd; \
"
# Exclude the app from main rootfs and pull extension targets
do_rootfs[depends] += " \
    my-new-app-sysext:do_image_complete \
    my-new-app-confext:do_image_complete \
"

seed_factory_extensions() {
    install -d ${IMAGE_ROOTFS}/usr/share/factory-extensions
    
    # Copy all sysext images
    cp -L ${DEPLOY_DIR_IMAGE}/my-new-app-sysext-${MACHINE}.sysext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    
    # Copy all confext images
    cp -L ${DEPLOY_DIR_IMAGE}/my-new-app-confext-${MACHINE}.confext.raw ${IMAGE_ROOTFS}/usr/share/factory-extensions/
    
    chmod 0644 ${IMAGE_ROOTFS}/usr/share/factory-extensions/*.raw
}

setup_ssh_symlinks() {
    mkdir -p ${IMAGE_ROOTFS}/var/lib/ssh
    mkdir -p ${IMAGE_ROOTFS}/etc/ssh
    
    # The /var/empty directory is persistent and safe to create in rootfs
    install -d -m 0755 -o root -g root ${IMAGE_ROOTFS}/var/empty

    rm -f ${IMAGE_ROOTFS}/etc/ssh/ssh_host_*
    ln -sf ../../var/lib/ssh/ssh_host_rsa_key ${IMAGE_ROOTFS}/etc/ssh/ssh_host_rsa_key
    ln -sf ../../var/lib/ssh/ssh_host_ecdsa_key ${IMAGE_ROOTFS}/etc/ssh/ssh_host_ecdsa_key
    ln -sf ../../var/lib/ssh/ssh_host_ed25519_key ${IMAGE_ROOTFS}/etc/ssh/ssh_host_ed25519_key
}

setup_readonly_machine_id() {
    rm -f ${IMAGE_ROOTFS}/etc/machine-id
    ln -sf /var/machine-id ${IMAGE_ROOTFS}/etc/machine-id
}

# FIX 2: Create a systemd-tmpfiles rule to guarantee /run/sshd exists on every boot
setup_sshd_tmpfiles() {
    install -d ${IMAGE_ROOTFS}/usr/lib/tmpfiles.d
    echo "d /run/sshd 0755 root root - -" > ${IMAGE_ROOTFS}/usr/lib/tmpfiles.d/sshd.conf
}

ROOTFS_POSTPROCESS_COMMAND += "setup_readonly_machine_id; seed_factory_extensions; setup_ssh_symlinks; setup_sshd_tmpfiles; "