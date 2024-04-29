#!/bin/bash
# script to build local Docker image using Buildah.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOG_FILE=${SCRIPT_DIR}/build-local-docker-image.log
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

function build_image() {
    # build container image
     #buildah --storage-driver=overlay bud --no-cache -f ./tekton/Dockerfiles/Dockerfile.copying-artifacts -t nocodb-runner-image .  (our custom image)
     buildah login selfhosted.jfrog.io --username=tekton --password=Tekton123@
     buildah --storage-driver=overlay bud --no-cache -f ${SCRIPT_DIR}/packages/nocodb/Dockerfile.local -t nocodb-runner-new-image .
     buildah --storage-driver=overlay tag nocodb-runner-new-image selfhosted.jfrog.io/nocodb-deps/nocodb-runner-image:0.6
     buildah --storage-driver=overlay --creds tekton:Tekton123@ push selfhosted.jfrog.io/nocodb-deps/nocodb-runner-image:0.6
}

function log_message() {
    if [[ ${ERROR} != "" ]];
    then
        >&2 echo "build failed, Please check build-local-docker-image.log for more details"
        >&2 echo "ERROR: ${ERROR}"
        exit 1
    else
        echo 'container image with tag "nocodb-local" built successfully. Use below sample command to run the container'
        echo 'podman run -d -p 3333:8080 --name nocodb-local nocodb-local '
    fi
}

echo "Info: Installing dependencies" | tee ${LOG_FILE}
install_dependencies 1>> ${LOG_FILE} 2>> ${LOG_FILE}

echo "Info: Building nc-gui" | tee -a ${LOG_FILE}
build_gui 1>> ${LOG_FILE} 2>> ${LOG_FILE}

echo "Info: Copying nc-gui build to nocodb dir" | tee -a ${LOG_FILE}
copy_gui_artifacts 1>> ${LOG_FILE} 2>> ${LOG_FILE}

echo "Info: Packaging nocodb, including nocodb-sdk and nc-gui" | tee -a ${LOG_FILE}
package_nocodb 1>> ${LOG_FILE} 2>> ${LOG_FILE}

if [[ ${ERROR} == "" ]]; then
    echo "Info: Building container image" | tee -a ${LOG_FILE}
    build_image 1>> ${LOG_FILE} 2>> ${LOG_FILE}
fi

log_message | tee -a ${LOG_FILE}
