#!/usr/bin/env bash
set -ex

PROJECT_DIR="$(
  cd "$(dirname "$BASH_SOURCE/../")"
  pwd
)"

SCRIPT_DIR="$(
  cd "$(dirname "$BASH_SOURCE")"
  pwd
)"

function cleanup() {
    echo "[test-containerdisk] cleanup"
    if [ -z $DEBUG ]; then
      kubectl delete vmi $VMI_NAME --ignore-not-found=true || true
      pushd $kubevirt_dir
        make cluster-down
      popd
      rm -rf $kubevirt_dir
      rm -rf "${IMAGE_NAME}_build"
    fi
}

readonly KUBEVIRT_URL="https://github.com/kubevirt/kubevirt"

trap 'cleanup' EXIT SIGINT

# Fetch KubeVirt
kubevirt_dir=$(mktemp -d -p /tmp -t image-build.kubevirt.XXXX)
git clone $KUBEVIRT_URL --depth=1 --branch=master --single-branch $kubevirt_dir

# Spin-up kubernetes cluster with KubeVirt on top
pushd $kubevirt_dir
  if [ -z $DEBUG ]; then
    export KUBEVIRT_PROVIDER=k8s-1.17
    make cluster-down cluster-up cluster-sync
  fi

  export KUBECONFIG="$($kubevirt_dir/cluster-up/kubeconfig.sh)"
  cluster_registry_port="$($kubevirt_dir/cluster-up/cli.sh ports registry | tr -d '\r')"
popd 

# Create container-disk image from example-cloud-config
export REGISTRY="localhost:$cluster_registry_port"
export REPOSITORY="kubevirt"
export IMAGE_NAME="fedora-example"
export TAG="32"
export CLOUD_CONFIG_PATH="${SCRIPT_DIR}/example/example-cloud-config"
export VM_IMAGE_URL="$(cat ${SCRIPT_DIR}/example/example-image-url)"

# Create new container-disk image from the customized VM image
# and push to cluster registry
export CUSTOMIZE_IMAGE_SCRIPT="${PROJECT_DIR}/customize-image/customize-image.sh"
${SCRIPT_DIR}/create-push-containerdisk.sh

# Create VM from the new image and check if it is ready
export VMI_NAME="testvm1"
export VMI_IMAGE="registry:5000/${REPOSITORY}/${IMAGE_NAME}:${TAG}"
VMI_YAML="${SCRIPT_DIR}/vmi-test-image.yaml"
envsubst < "$VMI_YAML" | kubectl apply -f -

# Wait until qemu-guest-agent service is up
kubectl wait --for=condition=AgentConnected vmi $VMI_NAME --timeout 5m

#TODO: run KubeVirt smoke tests from VM's
