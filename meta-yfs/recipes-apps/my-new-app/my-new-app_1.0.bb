SUMMARY = "EdgeOS Application Service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://main.py \
    file://my-new-app.service \
"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "my-new-app.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} = " \
    python3-core \
    python3-json \
    python3-netserver \
"

do_install() {
    install -d ${D}${prefix}/lib/my-new-app
    install -m 0755 ${S}/main.py ${D}${prefix}/lib/my-new-app/main.py
    echo "1.0" > ${D}${prefix}/lib/my-new-app/version

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/my-new-app.service ${D}${systemd_system_unitdir}/my-new-app.service
}

FILES:${PN} += " \
    ${prefix}/lib/my-new-app/main.py \
    ${prefix}/lib/my-new-app/version \
    ${systemd_system_unitdir}/my-new-app.service \
"