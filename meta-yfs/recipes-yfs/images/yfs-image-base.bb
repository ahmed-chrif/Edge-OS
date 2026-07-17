SUMMARY = "basic image"

LICENSE = "MIT"

inherit core-image
inherit image_types_tegra
inherit read-only-fs
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
