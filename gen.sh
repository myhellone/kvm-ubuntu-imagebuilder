#!/bin/bash

if [[ $(uname) == Darwin ]]; then
    vagrant destroy -f
    vagrant up
    exit 0
fi

if [[ $(uname) == Linux ]]; then
    cd /tmp
    export KEYFILE="${HOME}/.ssh/id_rsa.pub"
    export UBUNTU_MIRROR_URL="$(cat $OLDPWD/ubuntu-mirror.tmp)"
    for CN in precise saucy ; do
        $OLDPWD/buildimage.sh $CN
        if [[ $? -ne 0 ]]; then
            set -x
            set -v
            BD="/tmp/kvmbuild-${CN}"
            IM="/tmp/kvmbuild-${CN}.img"
            umount "$BD/dev"
            umount "$BD/proc"
            umount "$BD/sys"
            umount "$BD/boot"
            umount "$BD"
            vgchange -an vmvg0
            for LODEV in /dev/loop* ; do
                losetup -d $LODEV 2> /dev/null
            done
            for LODEV in /dev/mapper/loop*p1 ; do
                S=${LODEV#/dev/mapper/}
                S=${S%p1}
                kpartx -dv /dev/$S
                losetup -d /dev/$S
                unset S
            done
            for LODEV in /dev/loop* ; do
                losetup -d $LODEV 2> /dev/null
            done
            rm "$IM"
            exit 127
        fi
        mv /tmp/*${CN}64.qcow2 $OLDPWD
    done 
    exit 0
fi
