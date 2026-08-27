FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

SRC_URI += "\
    file://systemd.cfg \
    file://hash.cfg \
    file://part-format.cfg \
    file://archive.cfg \
    file://raw.cfg \
    file://disable-uboot.cfg \
    file://swupdate-web.service \
    file://custom-www/index.html \
    file://custom-www/style.css \
    file://custom-www/script.js \
"

DEPENDS += "e2fsprogs libarchive"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "swupdate-web.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
do_install:append() {
    rm -rf ${D}${sysconfdir}/swupdate.cfg
    rm -rf ${D}/www/*

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/swupdate-web.service ${D}${systemd_system_unitdir}/swupdate-web.service

    install -d ${D}/www
    install -m 0644 ${WORKDIR}/custom-www/index.html ${D}/www/
    install -m 0644 ${WORKDIR}/custom-www/style.css ${D}/www/
    install -m 0644 ${WORKDIR}/custom-www/script.js ${D}/www/
}

FILES:${PN} += "${systemd_system_unitdir}/swupdate-web.service"

FILES:${PN}-www = " \
    /www \
    /www/index.html \
    /www/style.css \
    /www/script.js \
"