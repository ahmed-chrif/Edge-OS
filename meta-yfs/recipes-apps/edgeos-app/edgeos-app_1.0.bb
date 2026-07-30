SUMMARY = "EdgeOS Health & Telemetry Microservice"
DESCRIPTION = "Production-grade C microservice providing live telemetry JSON API over HTTP"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://main.c \
    file://edgeos-app.service \
"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "edgeos-app.service"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ${WORKDIR}/main.c -o edgeos-app
}

do_install() {
    # Install binary into /usr/bin
    install -d ${D}${bindir}
    install -m 0755 edgeos-app ${D}${bindir}/edgeos-app

    # Install systemd service unit
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-app.service ${D}${systemd_system_unitdir}/edgeos-app.service
}

FILES:${PN} += " \
    ${bindir}/edgeos-app \
    ${systemd_system_unitdir}/edgeos-app.service \
"