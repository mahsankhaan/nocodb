#!/bin/bash
# script to build local Docker image using Buildah.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_FILE=${SCRIPT_DIR}/build-local.log
ERROR=""

function install_dependencies() {
    # Install all dependencies
    cd ${SCRIPT_DIR}
    pnpm i || ERROR="install_dependencies failed"
}

function build_gui() {
    # build nc-gui
    export NODE_OPTIONS="--max_old_space_size=16384"
    # generate static build of nc-gui
    cd ${SCRIPT_DIR}/packages/nc-gui
    pnpm run generate || ERROR="gui build failed"
}

function copy_gui_artifacts() {
     # copy nc-gui build to nocodb dir
    rsync -rvzh --delete ./dist/ ${SCRIPT_DIR}/packages/nocodb/docker/nc-gui/ || ERROR="copy_gui_artifacts failed"
}

function package_nocodb() {
    # build nocodb ( pack nocodb-sdk and nc-gui )
    cd ${SCRIPT_DIR}/packages/nocodb
    EE=true ${SCRIPT_DIR}/node_modules/.bin/webpack --config ${SCRIPT_DIR}/packages/nocodb/webpack.local.config.js || ERROR="package_nocodb failed"
}

echo "Info: Installing dependencies" | tee ${LOG_FILE}
install_dependencies 1>> ${LOG_FILE} 2>> ${LOG_FILE}

echo "Info: Building nc-gui" | tee -a ${LOG_FILE}
build_gui 1>> ${LOG_FILE} 2>> ${LOG_FILE}

echo "Info: Copying nc-gui build to nocodb dir" | tee -a ${LOG_FILE}
copy_gui_artifacts 1>> ${LOG_FILE} 2>> ${LOG_FILE}

echo "Info: Packaging nocodb, including nocodb-sdk and nc-gui" | tee -a ${LOG_FILE}
package_nocodb 1>> ${LOG_FILE} 2>> ${LOG_FILE}

