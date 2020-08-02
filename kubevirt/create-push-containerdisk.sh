#!/usr/bin/env bash
set -exuo pipefail

PROJECT_DIR="$(
  cd "$(dirname "$BASH_SOURCE/../")"
  pwd
)"

SCRIPT_DIR="$(
  cd "$(dirname "$BASH_SOURCE")"
  pwd
)"

export CUSTOMIZE_IMAGE_SCRIPT=${CUSTOMIZE_IMAGE_SCRIPT:-"${PROJECT_DIR}/customize_image/customize_image.sh"}

function customize_image() {
  local source_image=$1
  local customized_image=$2
  local cloud_config=$3

  # Backup the VM image and pass copy of the original image
  # in case customizing script fail.
  vm_image_temp="temp-${source_image}"
  cp "$source_image" "$vm_image_temp"

  # TODO: convert this script and its dependencies to container
  ${CUSTOMIZE_IMAGE_SCRIPT} "$vm_image_temp" "$customized_image" "$cloud_config"

  # Backup no longer needed.
  rm -f "$vm_image_temp"
}

function cleanup() {
    echo "[create-push-vm-image] cleanup"
    rm -f "temp-${VM_IMAGE}"
    if [ $? -ne 0 ];then
      rm -rf "${build_directory}"
    fi
}

export REGISTRY=${REGISTRY:-docker.io}
export REPOSITORY=${REPOSITORY:-kubevirt}
export IMAGE_NAME=${IMAGE_NAME:-example-fedora}
export TAG=${TAG:-32}
export CLOUD_CONFIG_PATH=${CLOUD_CONFIG_PATH:-"${SCRIPT_DIR}/example/example-cloud-config"}
export VM_IMAGE_URL=${VM_IMAGE_URL:-$(cat "${SCRIPT_DIR}/example/example-image-url")}

readonly VM_IMAGE="source-image.qcow2"
readonly full_image_tag="${REGISTRY}/${REPOSITORY}/${IMAGE_NAME}:${TAG}"
readonly build_directory="${IMAGE_NAME}_build"
readonly new_vm_image_name="provisioned-image.qcow2"

trap 'cleanup' EXIT SIGINT

pushd "${SCRIPT_DIR}"
  cleanup

  if ! [ -e "$VM_IMAGE" ]; then
    # Download base VM image
    curl -L $VM_IMAGE_URL -o $VM_IMAGE
  fi

  mkdir "${build_directory}"

  customize_image "$VM_IMAGE" "${build_directory}/${new_vm_image_name}" "${CLOUD_CONFIG_PATH}"

  ${SCRIPT_DIR}/build-containerdisk.sh "${IMAGE_NAME}" "${TAG}" "${build_directory}/${new_vm_image_name}"

  ${SCRIPT_DIR}/publish-containerdisk.sh "${IMAGE_NAME}:${TAG}" "$full_image_tag"
popd
