SUMMARY = "Mounts volatile RAM overlays over read-only directories"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://volatile-overlays.sh \
    file://volatile-overlays.service \
"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "volatile-overlays.service"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/volatile-overlays.sh ${D}${sbindir}/volatile-overlays.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/volatile-overlays.service ${D}${systemd_system_unitdir}/volatile-overlays.service
}

FILES:${PN} += " \
    ${sbindir}/volatile-overlays.sh \
    ${systemd_system_unitdir}/volatile-overlays.service \
"