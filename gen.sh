#!/bin/bash
set -e

if [[ $(uname) == Darwin ]]; then
    vagrant destroy -f
    vagrant up
    exit 0
fi

if [[ $(uname) == Linux ]]; then
    mkdir -p /tmp/build.$$ && cd /tmp/build.$$
    cp $OLDPWD/authorized_keys .
    export UBUNTU_MIRROR_URL="$(cat $OLDPWD/ubuntu-mirror.tmp)"
    for D in precise saucy ; do 
        $OLDPWD/buildimage.sh $D
        mv ./*.qcow2 $OLDPWD
    done 
    exit 0
fi
