# KubeVirt VM's

This tool is targeted for KubeVirt developers, users or anyone who
would like to create KubeVirt VM's with container-disk,
without the hassle of installing and customizing the OS manually.

Use cases:
- VM's for Demos
- Pre-configured Kubevirt VM image for tests, for example:
    - Image with qemu-guest-agent installed and configured. 
    - Image with sriov drivers for sriov-lane images.
    - Image with DPDK package for testing DPDK applications on KubeVirt. 


## Create customized container-disk image for KubeVirt VM

In order to automate the process of customizing VM image,
build container-disk from it and push it to a registry use
`create-push-containderdisk.sh` script.

What this script does:
- Download VM image from given URL

- Customize VM image using `customize-image.sh` script, according to given cloud-config file.
  Keeping customizing image method loosely-coupled, so it will be easy to maintain.  

- Building container-disk image using `build-containerdisk.sh`
  according to the doc: 
  https://github.com/kubevirt/kubevirt/blob/master/docs/container-register-disks.md

- Push the new container-disk image to registry using `publish-containerdisk.sh`

Currently, image customization process done by spinning up live VM
it is necessary to add `sudo shutdown -h now` at the end of the cloud-config
`runcmd` block, so the script will not wait for user input.

You can use your own image customizing script by exporting the path to CUSTOMIZE_IMAGE_SCRIPT.

This script also exports the container image to .tar
file, so it will be easier to store or send.

## How to use:
```bash

# Create kubernetes cluster with Kubvirt
git clone https://github.com/kubevirt/kubevirt --depth=1 --branch=master --single-branch kubevirt
pushd kubevirt
  export KUBEVIRT_PROVIDER=k8s-1.17
  make cluster-up cluster-sync
popd

# Optional, You could point to local cluster registry for developent and tests.
# From kubevirt / kubevirtci directory
export REGISTRY="localhost:$(./cluster-up/cli.sh ports registry | tr -d '\r')"

# Set to which registry the image will be pushed
export REGISTRY=docker.io
export REPOSITORY=kubevirt

# Export image name and tag
export IMAGE_NAME="example"
export TAG="tests"

cd cluster-provision/images/container-disk-images/
# Export VM image URL:
export IMAGE_URL=$(cat example/example-image-url)

# Export cloud-config file
export CLOUD_CONFIG_PATH="example/example-cloud-config"
 
# Run script
./create-push-containerdisk.sh

# Create VM from the new image (requiers KubeVirt operator)
export VMI_NAME="testvm1"
export VMI_IMAGE="registry:5000/${REPOSITORY}/${IMAGE_NAME}:${TAG}"
VMI_YAML="vmi-test-image.yaml"
envsubst < "$VMI_YAML" | kubectl apply -f -

kubectl wait --for=condition=AgentConnected vmi $VMI_NAME --timeout 5m

virtctl console testvm1


# You could send / store the image .tar file: 
ls example_build/example-tests.tar

```

This script requires the following packages:
- cloud-utils
- docker-ce
- libvirt
- libguestfs
- qemu-img

## Build container-disk image

To build container-disk image form qcow2 image
file, use `build-containerdisk.sh` script.

This script also exports the container image to .tar
file, so it will be easier to store or send.

### Example:
```bash
image_name='example-fedora'
tag='tests'
vm_image='customized-image.qcow2'

./build-containerdisk.sh $image_name $tag $vm_image

# Generated image .tar file
ls "example-fedora_build/example-fedora-tests.tar"
```

## Push container-disk image

Create new container-disk image with `publish-containerdisk.sh` script.

### Example:
```bash
image_tag="example-fedora:tests"
target_tag="docker.io/kubevirt/example-fedora:tests"

./publish-containerdisk.sh $image_tag $target_tag
```

### Push the new image to local cluster registry:
```bash
# From kubevirtci / kubevirt directory
cluster_registry="localhost:$(./cluster-up/cli.sh ports registry | tr -d '\r')"

image_tag="example-fedora:tests"
target_tag="${cluster_registry}:example-fedora:tests"

./publish-containerdisk.sh $image_tag $target_tag
```
