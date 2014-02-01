#!/bin/bash

set -x
set -v
function detect_local_mirror () {
    AL="$(avahi-browse -p -t -r _ubuntumirror._tcp | grep '^=' | head -1)"
    if [ -n "$AL" ]; then
        NAME="$(echo \"$AL\" | cut -d';' -f 8)"
        PORT="$(echo \"$AL\" | cut -d';' -f 9)"
        UM="http://${NAME}:${PORT}/ubuntu"
        MOK="$(curl --head ${UM}/ls-lR.gz 2>&1 | grep '200 OK' | wc -l)"
        if [ $MOK -gt 0 ]; then
            echo "$UM"
        fi
    fi
}

function set_apt_mirror () {
    CN="$(lsb_release -c -s)"
    RPS="main restricted multiverse universe"
    echo "deb [arch=amd64] $1 $CN $RPS" > /etc/apt/sources.list.new
    for P in updates backports security ; do
        echo "deb [arch=amd64] $1 $CN-$P $RPS" >> /etc/apt/sources.list.new
    done
    mv /etc/apt/sources.list.new /etc/apt/sources.list
}

echo "UseDNS no" >> /etc/ssh/sshd_config
service ssh restart

cat > /etc/apt/apt.conf.d/99-vm-no-extras-please <<EOF
APT::Install-Recommends "false";
APT::Install-Suggest "false";
EOF

TM="http://10.0.1.149:8080/ubuntu"
TMOK="$(wget --connect-timeout=1 -O /dev/null $TM/ls-lR.gz 2>&1 | 
    grep '200 OK' | wc -l)"
if [[ $TMOK -gt 0 ]]; then
    set_apt_mirror "$TM"
else
    set_apt_mirror "mirror://mirrors.ubuntu.com/mirrors.txt"
fi

dpkg --remove-architecture i386
apt-get update
apt-get -y install avahi-utils jq curl

UM="$(detect_local_mirror)"
if [ -n "$UM" ]; then
    echo "Detected LAN ubuntu mirror at $UM - configuring!"
    set_apt_mirror "$UM"
fi
echo "**********************************************************"
echo "**********************************************************"
cat /etc/apt/sources.list
echo "**********************************************************"
echo "**********************************************************"
apt-get update
apt-get -y install kpartx debootstrap lvm2 qemu-utils python-vm-builder
apt-get -y remove libvirt-bin
service qemu-kvm stop
apt-get -y upgrade
