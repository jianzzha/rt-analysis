#!/bin/bash

set -e

if false; then
function DownloadImg() {
    # $1: coreos image name
    echo downloading image and signature
    wget https://stable.release.core-os.net/amd64-usr/current/$1.bz2{,.sig}
    if gpg --verify $1.bz2.sig; then
        bunzip2 ${master_image}.bz2
    else
        echo "failed to verified downloaded image, exit"
        exit 1
    fi
}
fi

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <vm number>"
    exit 1
fi

vm=coreos$1
mac_prefix=52:54:00:4e:f5:0
bridge=br-em1
img_format=qcow2
#master_image=coreos_production_qemu_image.img
image_path=/var/lib/libvirt/images

extra="console=ttyS0,115200"

echo undefine guest VM

vm_state=$(virsh list --all | grep $vm | awk '{print $3}')

if [[ ! -z ${vm_state} ]]; then
    virsh destroy $vm || true
    virsh undefine $vm
fi

echo "removing exisiting vm image $vm.${img_format}"
[ -e $vm.${img_format} ] && /usr/bin/rm -rf $vm.${img_format}

[ -d ${image_path} ] || sudo mkdir -p ${image_path} 
pushd ${image_path}
[ -e $vm.${img_format} ] && rm -rf $vm.${img_format} 

if false; then
echo checking master image
if ! [[ -e ${master_image} ]]; then
    if [[ -e ${master_image}.bz2.sig && -e ${master_image}.bz2 ]]; then
        echo checking image signature
        if gpg --verify ${master_image}.bz2.sig; then
            echo img signature verified, unzip image
            if ! [[ -e ${master_image} ]]; then
                bunzip2 ${master_image}.bz2
            fi
        else
            echo failed to verfy image signature
            echo remove exisiting images
            /usr/bin/rm -rf ${master_image}.bz2.sig ${master_image}.bz2
            [ -e ${master_image} ] && /usr/bin/rm -rf ${master_image}
            DownloadImg ${master_image}
        fi
    else
        DownloadImg ${master_image}
    fi
fi
echo creating new image based on ${master_image}
qemu-img create -f ${img_format} -b $master_image $vm.${img_format} 60G
fi

[ -e $vm.${img_format} ] || qemu-img create -f ${img_format} $vm.${img_format} 30G
popd

echo calling virt-install
virt-install --connect qemu:///system \
    --name=$vm \
    --virt-type=kvm \
    --disk path=$image_path/$vm.${img_format},format=${img_format},bus=virtio \
    --vcpus=2 \
    --memory=2048 \
    --network bridge=$bridge,mac=${mac_prefix}$1 \
    --os-type=linux \
    --os-variant=virtio26 \
    --serial pty \
    --serial file,path=/tmp/$vm.console \
    --vnc --noautoconsole \
    --pxe
