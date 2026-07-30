SUMMARY = "System extension containing Edge Telemetry App"
LICENSE = "MIT"

inherit sysext-image

# Include our app recipe in this sysext image
IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""

IMAGE_INSTALL = "edgeos-app"

IMAGE_FSTYPES = "raw"