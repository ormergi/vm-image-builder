#!/usr/bin/env bash
set -exuo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "$BASH_SOURCE[0]")"
  pwd
)"

function cleanup() {
  echo "[build-container-disk] cleanup"
  rm -f Dockerfile

  if [ $? -ne 0 ]; then
    rm -f "$tar_file"
    docker image rm "$full_image_tag"
  fi
}

image_name=$1
tag=$2
vm_image_file=$3

export TEMPLATE_DOCKERFILE=${TEMPLATE_DOCKERFILE:-$SCRIPT_DIR/Dockerfile.containerdisk}

parent_dir=$(basename "$(dirname "$vm_image_file")")
tar_file="${parent_dir}/${image_name}-${tag}.tar"
full_image_tag="${image_name}:${tag}"

trap 'cleanup' EXIT

export IMAGE=${vm_image_file}
envsubst < "$TEMPLATE_DOCKERFILE" > "Dockerfile"

docker build -t "$full_image_tag" .

docker save --output "$tar_file" "$full_image_tag"
