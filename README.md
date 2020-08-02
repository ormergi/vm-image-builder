# Customize VM images

This tool automates the process of customizing VM image
cloud-init API, this enable you to create new VM images with an ease
skipping the tedious out-of-the box experience installations

## How to use

To customize a VM image execute `customize-image.sh` script.
What this script does is:
- Create could-init ISO file from the given cloud-config file.
- Create VM with cloud-init attached disk.
- Export the VM image to qcow2 file.

This script uses cloud-init in order to customize the VM image,
pass cloud-config file path with the changes you would like
to apply according to cloud-config API:
https://cloudinit.readthedocs.io/en/latest/topics/examples.html

this script requires:
- cloud-utils
- virt-install
- Libguestfs
- qemu-img
    

Once executed you should have a login prompt to the VM.
If extra steps needed login with username fedora and password fedora, 
execute what's needed, when finished shutdown the VM:
```bash
sudo shutdown -h now
```

### Example:
```bash

cd customize-image
curl -L $(cat example/example-image-url) -o image.qcow2

# Set source VM image file path, and the path to save
image_path="image.qcow2"
new_image_path="customized-image.qcow2"

# Set cloud-config configuration file path
cloud_config="example/example-cloud-config"

./customize-image.sh "$image_path" "$new_image_path" "$cloud_config"
```

# Kubevirt VM images

Creating KubeVirt VM's container-disk images in possible
[kubevirt/README.md](https://github.com/ormergi/vm-image-builder/blob/master/kubevirt/README.md)
