SUMMARY = "EdgeOS base immutable image"
LICENSE = "MIT"
inherit core-image image_types_tegra read-only-fs

IMAGE_INSTALL:append = " persistent-mount"
