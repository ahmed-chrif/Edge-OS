# Upstream openssh already inherits useradd and sets USERADD_PACKAGES.
# Use append/override operators rather than completely redefining the parameters.

USERADD_PARAM:${PN}-sshd = "--system --home-dir /var/empty --no-create-home --shell /sbin/nologin --user-group sshd"