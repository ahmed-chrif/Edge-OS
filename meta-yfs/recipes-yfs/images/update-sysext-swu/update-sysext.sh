if [ "$1" = "postinst" ]; then
    echo "Refreshing systemd-sysext..."
    systemd-sysext refresh || echo "WARNING: systemd-sysext refresh failed"

    systemctl daemon-reload
    systemctl restart my-new-app.service || echo "WARNING: my-new-app.service restart failed"
    exit 0
fi