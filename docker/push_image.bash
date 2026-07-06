#! /bin/bash
set -ex
docker tag yocto-builder $1
docker push $1