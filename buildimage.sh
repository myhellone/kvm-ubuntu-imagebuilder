#!/bin/bash

set -e
set -v
set -x

R="saucy"

DATE="$(date +%Y%m%d)"
ROOTPW="7c493cc530734f4c11e00bcecadb7b73"

function detect_local_mirror () {
    AL="$(avahi-browse -p -t -r _ubuntumirror._tcp | grep '^=' | head -1)"
    UM=""
    if [ -n "$AL" ]; then
        NAME="$(echo \"$AL\" | cut -d\; -f 8)"
        PORT="$(echo \"$AL\" | cut -d\; -f 9)"
        if [ $PORT -eq 80 ]; then
            UM="http://${NAME}/ubuntu/"
        else
            UM="http://${NAME}:${PORT}/ubuntu/"
        fi

    fi
    if [ -z "$UM" ]; then
        # maybe try hetzner mirror?
        UM="http://mirror.hetzner.de/ubuntu/packages/" 
        TF="${UM}/dists/${R}/Release"
        MOK="$(curl --head ${TF} 2>&1 | grep '200 OK' | wc -l)"
        if [ $MOK -gt 0 ]; then
            echo "$UM"
        else
            echo "http://archive.ubuntu.com/ubuntu/"
        fi  
    else 
        echo "$UM"
    fi
}

UM="$(detect_local_mirror)"

DEST="/eeqj-${R}64"

mkdir -p /td-$R
#strace -o /trace -ff -- \
vmbuilder \
    kvm ubuntu \
    --dest $DEST \
    --tmpfs - \
    --temp /td-$R \
    -v --debug \
    --suite $R \
    --config ./vmbuilder.cfg \
    --execscript ./${R}-post.sh \
    --mirror $UM \
    --security-mirror $UM
