#!/usr/bin/env bash
echo "disable firewalld and selinux"
systemctl disable --now firewalld
setenforce 0
sed -i s/^SELINUX=.*/SELINUX=disabled/ /etc/selinux/config 

if ! pgrep libvirtd; then
    echo "install libvirt"
    yum install -y libvirt libvirt-devel libvirt-daemon-kvm qemu-kvm virt-install
    systemctl enable libvirtd
fi

echo "update libvirt conf files"
sed -i '/^listen_tls/d' /etc/libvirt/libvirtd.conf
sed -i '/^listen_tcp/d' /etc/libvirt/libvirtd.conf
sed -i '/^auth_tcp/d' /etc/libvirt/libvirtd.conf
sed -i '/^tcp_port/d' /etc/libvirt/libvirtd.conf
echo 'listen_tls = 0' >> /etc/libvirt/libvirtd.conf
echo 'listen_tcp = 1' >> /etc/libvirt/libvirtd.conf
echo 'auth_tcp = "none"' >> /etc/libvirt/libvirtd.conf
echo 'tcp_port = "16509"' >> /etc/libvirt/libvirtd.conf

sed -i '/^LIBVIRTD_ARG/d' /etc/sysconfig/libvirtd
echo 'LIBVIRTD_ARGS="--listen"' >> /etc/sysconfig/libvirtd

systemctl restart libvirtd

if ! pgrep matchbox; then
    echo "install matchbox"
    wget -O /tmp/matchbox.tar.gz https://github.com/poseidon/matchbox/releases/download/v0.8.0/matchbox-v0.8.0-linux-amd64.tar.gz 
    pushd /tmp
    tar zxf matchbox.tar.gz
    cp matchbox*/matchbox /usr/local/bin
    cp matchbox*/contrib/systemd/matchbox-local.service /etc/systemd/system/matchbox.service
    sed -i 's/User=matchbox/User=root/' /etc/systemd/system/matchbox.service
    sed -i 's/Group=matchbox/Group=root/' /etc/systemd/system/matchbox.service
    systemctl start matchbox
    rm -rf /tmp/matchbox*
    popd
    cp -rf matchbox/{groups,profiles} /var/lib/matchbox/ 
fi    

mkdir -p /var/lib/matchbox/{assets,ignition}

echo "get latest images"
wget -O /tmp/rhcos.json https://raw.githubusercontent.com/openshift/installer/master/data/data/rhcos.json
baseURI=`jq -r .baseURI /tmp/rhcos.json`
initramfs=`jq -r .images.initramfs.path /tmp/rhcos.json`
kernel=`jq -r .images.kernel.path /tmp/rhcos.json`
metal=`jq -r .images.metal.path /tmp/rhcos.json`
rm -rf /tmp/rhcos.json

if [ ! -f /var/lib/matchbox/assets/${initramfs} ]; then
    echo "update ${initramfs}"
    rm -rf /var/lib/matchbox/assets/rhcos-*installer-initramfs*
    wget -O /var/lib/matchbox/assets/${initramfs} $baseURI/${initramfs}
    echo "update profiles to ${initramfs}"
    for f in bootstrap.json master.json vmworker.json; do
        tmp=$(mktemp)
        jq ".boot.initrd[0] = \"/assets/${initramfs}\"" /var/lib/matchbox/profiles/$f > "$tmp"
        mv "$tmp" /var/lib/matchbox/profiles/$f
    done
fi
    
if [ ! -f /var/lib/matchbox/assets/${kernel} ]; then
    echo "update ${kernel}"
    rm -rf /var/lib/matchbox/assets/rhcos-*installer-kernel*
    wget -O /var/lib/matchbox/assets/${kernel} $baseURI/${kernel}
    echo "update profiles to ${kernel}"
    for f in bootstrap.json master.json vmworker.json; do
        tmp=$(mktemp)
        jq ".boot.kernel = \"/assets/${kernel}\"" /var/lib/matchbox/profiles/$f > "$tmp"
        mv "$tmp" /var/lib/matchbox/profiles/$f
    done
fi

if [ ! -f /var/lib/matchbox/assets/${metal} ]; then
    echo "update ${metal}"
    rm -rf /var/lib/matchbox/assets/rhcos-*metal*
    wget -O /var/lib/matchbox/assets/${metal} $baseURI/${metal}
    echo "update profiles to ${metal}"
    for f in bootstrap.json master.json worker.json vmworker.json; do
        sed -i -r "s%(coreos.inst.image_url=.*/assets/).*metal.x86_64.raw.gz%\1${metal}%" /var/lib/matchbox/profiles/$f 
    done 
fi

fInitramfs=`ls /var/lib/matchbox/assets/fedora-coreos*installer-initramfs* 2>/dev/null`
if (( $? != 0 )); then
    fInitramfs="fedora-coreos-30.20191014.0-installer-initramfs.x86_64.img"
    echo "download ${fInitramfs}" 
    wget -O /var/lib/matchbox/assets/${fInitramfs} https://builds.coreos.fedoraproject.org/prod/streams/testing/builds/30.20191014.0/x86_64/${fInitramfs}
    echo "update profiles to ${fInitramfs}"
    tmp=$(mktemp)
    jq ".boot.initrd[0] = \"/assets/${fInitramfs}\"" /var/lib/matchbox/profiles/worker.json > "$tmp"
    mv -f "$tmp" /var/lib/matchbox/profiles/worker.json 
fi

fkernel=`ls /var/lib/matchbox/assets/fedora-coreos*installer-kernel* 2>/dev/null`
if (( $? != 0 )); then
    fkernel="fedora-coreos-30.20191014.0-installer-kernel-x86_64"
    echo "download ${fkernel}"
    wget -O /var/lib/matchbox/assets/${fkernel} https://builds.coreos.fedoraproject.org/prod/streams/testing/builds/30.20191014.0/x86_64/${fkernel}
    echo "update profiles to ${fkernel}"
    tmp=$(mktemp)
    jq ".boot.kernel = \"/assets/${fkernel}\"" /var/lib/matchbox/profiles/worker.json > "$tmp"
    mv -f "$tmp" /var/lib/matchbox/profiles/worker.json 
fi

echo "get openshift installer"
[ -d go/src/github.com/openshift/installer ] || go get -d github.com/jianzzha/installer
pushd ~/go/src/github.com/openshift/installer
echo "get binary that support libvirt"
git checkout vm-as-baremetal
[ -f bin/openshift-install ] || TAGS=libvirt hack/build.sh
cp -f bin/openshift-install /usr/local/bin/

echo "destroy exsiting cluster if exists"
if [ -e ~/ocp-install ]; then
    [ -e ~/ocp-install/metadata.json ] && openshift-install --dir ~/ocp-install destroy cluster
    rm -rf ~/ocp-install
fi

echo "set up routing"
popd && ./iptable-setup.sh && sysctl -w net.ipv4.ip_forward=1

echo "setup haproxy"
yum install -y haproxy
line=$(sed -n '1p' haproxy.cfg)
if ! grep "$line" /etc/haproxy/haproxy.cfg; then
    cat haproxy.cfg >> /etc/haproxy/haproxy.cfg
fi
systemctl restart haproxy

./setup-bridge.sh

echo "stop NetworkManager in case it controls dnsmasq" && systemctl stop NetworkManager
echo "stop exisiting dnsmasq"
killall dnsmasq
echo "close tmux dnsmasq session" && tmux kill-session -t "dnsmasq" 2>/dev/null
echo "create new tmux session for dnsmasq"
tmux new-session -d -s "dnsmasq" "cd $PWD/dnsmasq-setup; dnsmasq -d -q --conf-file=dnsmasq.conf"

if [ -z "$1" ]; then
    RELEASE="4.3"
else
    RELEASE=$1
fi

mkdir ~/ocp-install
cp install-config.yaml  ~/ocp-install/

echo "build ignition files"
OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.svc.ci.openshift.org/ocp/release:${RELEASE}" openshift-install --dir ~/ocp-install/ create ignition-configs
cp -f ~/ocp-install/*.ign /var/lib/matchbox/ignition/
echo "create cluster"
openshift-install --dir ~/ocp-install/ create cluster
