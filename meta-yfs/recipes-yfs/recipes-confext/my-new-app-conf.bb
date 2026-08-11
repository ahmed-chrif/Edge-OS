SUMMARY = "Configuration files for my-new-app"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://my-new-app.conf"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/my-new-app
    install -m 0644 ${WORKDIR}/my-new-app.conf ${D}${sysconfdir}/my-new-app/my-new-app.conf
}

FILES:${PN} += "${sysconfdir}/my-new-app/my-new-app.conf"