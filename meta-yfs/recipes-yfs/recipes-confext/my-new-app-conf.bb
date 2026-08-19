SUMMARY = "Configuration files for my-new-app"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://my-new-app.conf"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/my-new-app
    install -m 0644 ${WORKDIR}/my-new-app.conf ${D}${sysconfdir}/my-new-app/my-new-app.conf

    # 1. Create the systemd target directory in /etc
    install -d ${D}${sysconfdir}/systemd/system/multi-user.target.wants

    # 2. Bake the enable symlink pointing to the app service in /usr
    ln -s /usr/lib/systemd/system/my-new-app.service \
          ${D}${sysconfdir}/systemd/system/multi-user.target.wants/my-new-app.service
}

FILES:${PN} += " \
    ${sysconfdir}/my-new-app/my-new-app.conf \
    ${sysconfdir}/systemd/system/multi-user.target.wants/my-new-app.service \
"