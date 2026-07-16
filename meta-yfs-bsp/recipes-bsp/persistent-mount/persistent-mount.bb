SUMMARY = "Auto-formats and mounts custom persistent partition"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://format-persistent.sh \
    file://format-persistent.service \
"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "format-persistent.service"

do_install() {
    # Use sbindir to install into /usr/sbin/
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/format-persistent.sh ${D}${sbindir}/format-persistent.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/format-persistent.service ${D}${systemd_system_unitdir}/format-persistent.service
}

FILES:${PN} += " \
    ${sbindir}/format-persistent.sh \
    ${systemd_system_unitdir}/format-persistent.service \
"