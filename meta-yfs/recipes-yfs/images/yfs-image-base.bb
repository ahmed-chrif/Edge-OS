SUMMARY = "basic image"

LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "\
    ssh-server-openssh \
    package-management \
    bash-completion-pkgs \
    allow-root-login \
    empty-root-password \
    serial-autologin-root \
"

IMAGE_INSTALL:append:tegra = " l4t-usb-device-mode"

IMAGE_INSTALL:append:tegra = " nvidia-docker"
IMAGE_INSTALL += "\
    docker \
    docker-compose \
"
