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

# If swupdate-web.service is meant to be the main runner:
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "swupdate-web.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
TARGET_CFLAGS += "-DMG_MAX_RECV_SIZE=10485760"
do_install:append() {
    # Remove default static config in favor of generated config
    rm -rf ${D}${sysconfdir}/swupdate.cfg

    # Wipe upstream default web UI files to avoid mixing stock assets with custom UI
    rm -rf ${D}/www/*

    # Install custom systemd service unit
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/swupdate-web.service ${D}${systemd_system_unitdir}/swupdate-web.service

    # Install custom Mongoose Web Server UI files
    install -d ${D}/www
    install -m 0644 ${WORKDIR}/custom-www/index.html ${D}/www/
    install -m 0644 ${WORKDIR}/custom-www/style.css ${D}/www/
    install -m 0644 ${WORKDIR}/custom-www/script.js ${D}/www/
}

# Core package gets the service file
FILES:${PN} += "${systemd_system_unitdir}/swupdate-web.service"

# Assign custom web UI files explicitly to swupdate-www
FILES:${PN}-www = " \
    /www \
    /www/index.html \
    /www/style.css \
    /www/script.js \
"