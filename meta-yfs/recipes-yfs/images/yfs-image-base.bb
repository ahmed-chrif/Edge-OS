SUMMARY = "basic image"

LICENSE = "MIT"

inherit core-image
inherit image_types_tegra

DATAFILE ?= "${IMAGE_BASENAME}-${MACHINE}.dataimg"
IMAGE_TEGRAFLASH_DATA ?= "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.dataimg"
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

# 1. Ensure the build environment has host tools ready to format ext4 filesystems
do_image_tegraflash[depends] += "e2fsprogs-native:do_populate_sysroot"

# 2. Write a function to dynamically manufacture the missing .dataimg file
generate_empty_data_image() {
    mkdir -p "${IMGDEPLOYDIR}"
    
    # Create a raw, blank 50MB file (adjust count size if you want a larger default layout)
    dd if=/dev/zero of="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.dataimg" bs=1M count=450
    
    # Format the file cleanly as an ext4 filesystem block
    mkfs.ext4 -F "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.dataimg"
}

# 3. Inject this function into the pre-processing chain of the image pipeline
IMAGE_PREPROCESS_COMMAND += "generate_empty_data_image; "