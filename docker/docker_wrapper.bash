#! /usr/bin/bash

set -e 

print_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [COMMAND]

This script sets up and runs a Yocto build environment inside a Docker container.

OPTIONS:
  -h, --help        Show this help message and exit

COMMAND             Command to run inside the Docker container
                    (default: /bin/bash)

ENVIRONMENT VARIABLES (can be set in .env):

  OE_UUID            UID to use inside container (default: current user)
  OE_GGID            GID to use inside container (default: current group)
  DOCKER_REPO        Docker repository name (default: yocto-builder)
  DOCKER_USER        Docker user name (default: builder)
  OE_BASE_DIR        Yocto base directory (default: parent of script directory)
  OE_BUILD_DIR       Build directory (default: OE_BASE_DIR/build)
  OE_DL_DIR          Download cache directory (default: OE_BUILD_DIR/downloads-dir)
  OE_SSTATE_DIR      Sstate cache directory (default: OE_BUILD_DIR/sstate-cache)
  DEBUG              If set, prints debug info (paths, volumes, env vars)

EXAMPLES:
  Run bash inside the container:
    $(basename "$0")

  Run a specific command inside the container:
    $(basename "$0") bitbake core-image-minimal

  Enable debug output:
    DEBUG=1 $(basename "$0") /bin/bash

EOF
}

# Show help if -h or --help is passed
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print_help
    exit 0
fi

create_file_if_missing() {
    if [ ! -f "$1" ]; then
        touch "$1"
        echo "[WARN]: file $1 did not exist, created."
    fi
}

create_folder_if_missing() {
    if [ ! -f "$1" ]; then
        mkdir -p "$1"
        echo "[WARN]: folder $1 did not exist, created."
    fi
}

default_if_unset() {
    local var_name="$1"
    local default_value="$2"
    local action="$3"

    # Only assign default if variable is unset or empty
    if [ -z "${!var_name}" ]; then
        [ "$action" = "warn"  ] && echo "[WARN] $var_name not set, using default: $default_value"
        # Safe assignment
        printf -v "$var_name" '%s' "$default_value"
    fi
}

require_path() {
    if [ ! -e "$1" ]; then
        echo "Error: $1 does not exist!" >&2
        exit 1
    fi
}


SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# if env file not found create it and set default values
ENV_FILE="${SCRIPT_DIR}/.env"
if [ ! -f $ENV_FILE  ]; then
    echo "[WARN] .env not found, creating defaults at $ENV_FILE"
    echo "[WARN] Edit this file to override default paths"

    create_file_if_missing $ENV_FILE
    {
        echo 'OE_BASE_DIR=$(readlink -f "$SCRIPT_DIR/..")'
        echo 'OE_BUILD_DIR="${OE_BASE_DIR}/build"' 
        echo 'OE_DL_DIR="${OE_BASE_DIR}/build/downloads-dir"' 
        echo 'OE_SSTATE_DIR="${OE_BASE_DIR}/build/sstate-cache"' 
    } > $ENV_FILE
    
fi

# load the env vars
source $ENV_FILE

# if a value is not set in .env use default
default_if_unset OE_UUID        "$(id -u)"
default_if_unset OE_GGID        "$(id -g)"
default_if_unset DOCKER_REPO    "yocto-builder"
default_if_unset DOCKER_USER    "builder"                             
default_if_unset OE_BASE_DIR    "$(readlink -f '$SCRIPT_DIR/..')"     
default_if_unset OE_BUILD_DIR   "${OE_BASE_DIR}/build"                "warn"
default_if_unset OE_DL_DIR      "${OE_BASE_DIR}/build/downloads-dir"  "warn"
default_if_unset OE_SSTATE_DIR  "${OE_BASE_DIR}/build/sstate-cache"   "warn"

# ensure env variables are set to correct paths
require_path $OE_BASE_DIR
require_path $OE_BUILD_DIR
require_path $OE_DL_DIR
require_path $OE_SSTATE_DIR

# map the git repo to a path inside the container
REPO_DIR="/workspace/$(basename $OE_BASE_DIR)"
MAP_BASE_DIR="--volume=$(readlink -f $OE_BASE_DIR):$REPO_DIR"

# map build sstate and download to the container
DL_DIR="/workspace/$(basename $OE_DL_DIR)"
SSTATE_DIR="/workspace/$(basename $OE_SSTATE_DIR)"
MAP_DL_DIR="--volume=$(readlink -f $OE_DL_DIR):$DL_DIR"
MAP_SSTATE_DIR="--volume=$(readlink -f $OE_SSTATE_DIR):$SSTATE_DIR"
MAP_BUILD_DIR="--volume=$(readlink -f $OE_BUILD_DIR):$REPO_DIR/build"

# map .gitconfig file
KAS_CONFIG_FILE="$SCRIPT_DIR/.kas_gitconfig"
create_file_if_missing $KAS_CONFIG_FILE
MAP_GIT_CONFIG="--volume=$KAS_CONFIG_FILE:/home/$DOCKER_USER/.gitconfig"
#MAP_KAS_GIT_CONFIG="--env GITCONFIG_FILE=$REPO_DIR/.kas_gitconfig"

# map .bash_history file
BASH_HISTORY_FILE="$SCRIPT_DIR/.bash_history"
MAP_BASH_HISTORY="--volume=$BASH_HISTORY_FILE:/home/$DOCKER_USER/.bash_history"
create_file_if_missing $BASH_HISTORY_FILE


if [ -n "$DEBUG" ]; then
    vars=(SCRIPT_DIR OE_UUID OE_GGID DOCKER_REPO DOCKER_USER OE_BASE_DIR OE_BUILD_DIR OE_SSTATE_DIR OE_DL_DIR MAP_BASE_DIR MAP_DL_DIR MAP_SSTATE_DIR MAP_BUILD_DIR MAP_BASH_HISTORY MAP_GIT_CONFIG)

    for v in "${vars[@]}"; do
        printf ">> %-20s : %s\n" "$v" "${!v}"
    done
fi

if [ "$#" -eq 0 ]; then
    CMD="/bin/bash"
else
    CMD="$@"
fi

BB_ENV_PASSTHROUGH_ADDITIONS="DL_DIR SSTATE_DIR"

docker run --rm \
        -it \
        $MAP_BASE_DIR \
        $MAP_DL_DIR \
        $MAP_SSTATE_DIR \
        $MAP_BUILD_DIR \
        $MAP_BASH_HISTORY \
        $MAP_GIT_CONFIG \
        $MAP_KAS_GIT_CONFIG \
        -w ${REPO_DIR} \
        --env BB_ENV_PASSTHROUGH_ADDITIONS="$BB_ENV_PASSTHROUGH_ADDITIONS" \
        --env DL_DIR="$DL_DIR" \
        --env SSTATE_DIR="$SSTATE_DIR" \
        --env GGID=${OE_GGID} \
        --env UUID=${OE_UUID} \
        --ulimit "nofile=1024:1048576" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        ${EXTRA_ARGS} ${DOCKER_REPO} $CMD

