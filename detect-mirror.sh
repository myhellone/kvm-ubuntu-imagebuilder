#!/bin/bash

# feel free to set MY_LOCAL_UBUNTU_MIRROR
# to make this try your local/lan copy first

TRY="
    $MY_LOCAL_UBUNTU_MIRROR
    http://mirror.localservice/ubuntu
    http://mirror.hetzner.de/ubuntu
"

CC="$(
    curl -w 1 -s https://freegeoip.net/json/ | 
    jq -r .country_code 2>/dev/null
)"

if [[ ! -z "$CC" ]]; then
    TRY+=" http://$CC.archive.ubuntu.com/ubuntu"
fi

TRY+=" http://archive.ubuntu.com/ubuntu"

for TRYMIRROR in $TRY ; do 
    TF="${TRYMIRROR}/dists/saucy/Release"
    MOK="$(curl -m 1 --head ${TF} 2>&1 | grep '200 OK' | wc -l)"
    if [ $MOK -gt 0 ]; then
        echo "$TRYMIRROR"
        exit 0
    fi
done

# give this one even if it failed above, it's not our fault
# you don't have internet access...
echo "http://archive.ubuntu.com/ubuntu"
exit 0
