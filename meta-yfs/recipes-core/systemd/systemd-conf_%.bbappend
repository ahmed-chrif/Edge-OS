FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://99-sysext.preset"

do_install:append() {
    install -d ${D}${systemd_unitdir}/system-preset
    install -m 0644 ${WORKDIR}/99-sysext.preset ${D}${systemd_unitdir}/system-preset/99-sysext.preset
}

# Add the newly installed preset path to the package's file list
FILES:${PN} += "${systemd_unitdir}/system-preset/99-sysext.preset"