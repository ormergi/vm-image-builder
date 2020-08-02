#!/usr/bin/env bash
set -exuo pipefail

function cleanup() {
  echo "[customize-image] cleanup"
  rm -rf "$CLOUD_INIT_ISO"
  virsh destroy "$DOMAIN_NAME" || true
  virsh undefine "$DOMAIN_NAME" || true

  if [ $? -ne 0 ]; then
    rm -f "$NEW_IMAGE"
  fi
}

IMAGE_PATH=$1
NEW_IMAGE=$2
CLOUD_CONFIG_PATH=$3

export OS_VARIANT=${OS_VARIANT:-fedora31}

readonly DOMAIN_NAME="provision-vm"
readonly CLOUD_INIT_ISO="cloudinit.iso"

if ! [ -f "${CLOUD_CONFIG_PATH}" ]; then
  CLOUD_CONFIG_PATH="user-cloud-config"
fi

trap 'cleanup' EXIT SIGINT

# Create cloud-init user data ISO
cloud-localds $CLOUD_INIT_ISO $CLOUD_CONFIG_PATH

echo "Customize image by booting a VM with
 the image and cloud-init disk
 press ctrl+] to exit"
virt-install \
  --memory 2048 \
  --vcpus 2 \
  --name $DOMAIN_NAME \
  --disk "$IMAGE_PATH",device=disk \
  --disk $CLOUD_INIT_ISO,device=cdrom \
  --os-type Linux \
  --os-variant "$OS_VARIANT" \
  --virt-type kvm \
  --graphics none \
  --network default \
  --import

virt-sysprep -d $DOMAIN_NAME --operations machine-id,bash-history,logfiles,tmp-files,net-hostname,net-hwaddr,customize --hostname ""

# Remove VM
virsh destroy $DOMAIN_NAME || true
virsh undefine $DOMAIN_NAME

# Remove cloud-init image
rm -rf $CLOUD_INIT_ISO

# Convert image"
qemu-img convert -c -O qcow2 "$IMAGE_PATH" "$NEW_IMAGE"
