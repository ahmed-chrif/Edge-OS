SUMMARY = "EdgeOS base immutable image"
LICENSE = "MIT"
inherit core-image image_types_tegra read-only-fs

IMAGE_INSTALL:append = " \
    persistent-mount \
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

ROOTFS_POSTPROCESS_COMMAND += "seed_factory_extensions; setup_ssh_symlinks; "
setup_sysext_ordering() {
    # Drop-in for systemd-sysext.service
    mkdir -p ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-sysext.service.d
    cat << 'EOF' > ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-sysext.service.d/override.conf
[Unit]
After=format-persistent.service
Requires=format-persistent.service
EOF

    # Drop-in for systemd-confext.service
    mkdir -p ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-confext.service.d
    cat << 'EOF' > ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-confext.service.d/override.conf
[Unit]
After=format-persistent.service
Requires=format-persistent.service
setup_sysext_ordering() {
    # 1. Drop-in for systemd-sysext.service (App Extensions)
    mkdir -p ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-sysext.service.d
    cat << 'EOF' > ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-sysext.service.d/override.conf
[Unit]
After=format-persistent.service
Requires=format-persistent.service

[Service]
ExecStart=
ExecStart=systemd-sysext --mutable=ephemeral merge
EOF

    # 2. Drop-in for systemd-confext.service (Config Extensions)
    mkdir -p ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-confext.service.d
    cat << 'EOF' > ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/systemd-confext.service.d/override.conf
[Unit]
After=format-persistent.service
Requires=format-persistent.service

[Service]
ExecStart=
ExecStart=systemd-confext --mutable=ephemeral merge
EOF

    # 3. FORCE ENABLE: Manually link them to sysinit.target to bypass the broken preset
    mkdir -p ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/sysinit.target.wants
    ln -sf ${systemd_system_unitdir}/systemd-sysext.service ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/sysinit.target.wants/systemd-sysext.service
    ln -sf ${systemd_system_unitdir}/systemd-confext.service ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/sysinit.target.wants/systemd-confext.service
}

ROOTFS_POSTPROCESS_COMMAND += "setup_sysext_ordering; "