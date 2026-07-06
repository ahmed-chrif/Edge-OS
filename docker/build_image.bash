#! /bin/bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

docker build -t yocto-builder $SCRIPT_DIR