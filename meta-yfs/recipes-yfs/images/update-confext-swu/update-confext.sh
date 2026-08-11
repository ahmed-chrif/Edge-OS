#!/bin/sh

if [ "$1" = "preinst" ]; then
    # Ensure persistent target directories exist before extraction
    mkdir -p /var/lib/extensions
    mkdir -p /var/lib/confexts
    exit 0
fi

if [ "$1" = "postinst" ]; then
    echo "Refreshing systemd-sysext..."
    systemd-sysext refresh || echo "WARNING: systemd-sysext refresh failed"

    echo "Refreshing systemd-confext..."
    systemd-confext refresh || echo "WARNING: systemd-confext refresh failed"

    # Reload systemd manager and restart application to apply new binaries & port (8080 -> 9000)
    systemctl daemon-reload
    systemctl restart my-new-app.service || echo "WARNING: my-new-app.service restart failed"

    exit 0
fi

exit 0