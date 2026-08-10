SUMMARY = "EdgeOS runtime extension control (Avocado-style)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://00-edgeos.preset \
    file://edgeos-extension.service \
    file://edgeos-ensure-extensions.service \
    file://generate-machine-id.service \
"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"  
SYSTEMD_SERVICE:${PN} = " \
    edgeos-extension.service \
    edgeos-ensure-extensions.service \
"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    # Install extension services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-extension.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edgeos-ensure-extensions.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/generate-machine-id.service ${D}${systemd_system_unitdir}/

    # Install the preset file to disable stock sysext/confext & enable generate-machine-id
    install -d ${D}${sysconfdir}/systemd/system-preset
    install -m 0644 ${WORKDIR}/00-edgeos.preset ${D}${sysconfdir}/systemd/system-preset/00-edgeos.preset
}

FILES:${PN} += " \
    ${sysconfdir}/systemd/system-preset/00-edgeos.preset \
    ${systemd_system_unitdir}/edgeos-extension.service \
    ${systemd_system_unitdir}/edgeos-ensure-extensions.service \
    ${systemd_system_unitdir}/generate-machine-id.service \
"