#!/bin/bash
set -e
set -v
set -x

SAVESPACE=1
WITHCHEF=1
ORGNAME="eeqj"
DSIZE="25G"         # disk size

# releases we support right now
SUPPORTED="precise saucy"

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <codename>" > /dev/stderr
    echo "supported ubuntu releases: $SUPPORTED" > /dev/stderr
    exit 127
fi
R="$1"          # release
if ! [[ "$SUPPORTED" =~ "$R" ]] ; then
    echo "$0: unsupported ubuntu release $R, sorry." > /dev/stderr
    exit 127
fi

MR="/tmp/kvmbuild-${R}"
RI="/tmp/kvmbuild-${R}.img"      # raw image
VGN="vmvg0"         # volume group name
DATE="$(date -u +%Y%m%d)"
LONGDATE="$(date -u +%Y-%m-%dT%H:%M:%S%z)"
LOOPDEV="$(losetup -f)"
LDBASE="$(basename $LOOPDEV)"
ROOTPW="root"

if [[ -e /dev/$VGN ]]; then
    echo "$0: error, vg $VGN already exists" > /dev/stderr
    exit 127
fi

if [[ -e "$MR" ]]; then
    echo "$0: error, chroot dir $MR already exists" > /dev/stderr
    exit 127
fi

if [[ -e "$RI" ]]; then
    echo "$0: error, intermediate image file $RI already exists" > /dev/stderr
    exit 127
fi

function detect_local_mirror () {
    TF="${UBUNTU_MIRROR_URL}/dists/${R}/Release"
    MOK="$(curl -m 1 --head ${TF} 2>&1 | grep '200 OK' | wc -l)"
    if [ $MOK -gt 0 ]; then
        echo "$UBUNTU_MIRROR_URL"
    else
        echo "http://archive.ubuntu.com/ubuntu/"
    fi  
}

UM="$(detect_local_mirror)"

# create sparse file and partition it
dd if=/dev/zero of=$RI bs=1 count=0 seek=$DSIZE
parted -s $RI mklabel msdos
parted -a optimal $RI mkpart primary 0% 200MiB
parted -a optimal $RI mkpart primary 200MiB 100%
parted $RI set 1 boot on
losetup $LOOPDEV $RI
kpartx -av $LOOPDEV
BOOTPARTLOOP="$(losetup -f)"
losetup $BOOTPARTLOOP /dev/mapper/${LDBASE}p1

# make boot filesystem:
if [[ "$R" == "saucy" ]]; then
    FSTYPE="ext4"
else
    FSTYPE="ext3"
fi

mkfs.${FSTYPE} -L BOOT $BOOTPARTLOOP
tune2fs -c -1 $BOOTPARTLOOP

# create root vg and filesystem:
pvcreate /dev/mapper/${LDBASE}p2
vgcreate $VGN /dev/mapper/${LDBASE}p2
lvcreate -l 100%FREE -n root $VGN
mkfs.${FSTYPE} -L ROOT /dev/$VGN/root

# mount stuff
mkdir -p $MR
MR="$(readlink -f $MR)"
mount /dev/$VGN/root $MR
mkdir $MR/boot
mount $BOOTPARTLOOP $MR/boot

# install base:
echo "*** installing base $R system from $UM..."
debootstrap --arch amd64 $R $MR $UM

# temporary config for install:
RPS="main restricted multiverse universe"
echo "deb $UM $R $RPS" > $MR/etc/apt/sources.list
for P in updates backports security ; do
    echo "deb $UM $R-$P $RPS" >> $MR/etc/apt/sources.list
done

# disable apt installation exuberance
cat > $MR/etc/apt/apt.conf.d/99-vm-no-extras-please <<EOF
APT::Install-Recommends "false";
APT::Install-Suggest "false";
EOF

# default to google resolver for now
cat > $MR/etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

cat > $MR/etc/environment <<EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LANGUAGE="en_US:en"
LANG="en_US.UTF-8"
ROOT_IMAGE_BUILD_DAY="$DATE"
ROOT_IMAGE_BUILD_DATE="$LONGDATE"
ROOT_IMAGE_BUILD_ORG="$ORGNAME"
EOF

chroot $MR locale-gen en_US.UTF-8
chroot $MR dpkg-reconfigure locales

echo 'cd /dev && MAKEDEV generic 2>/dev/null' | chroot $MR 

BUUID="$(blkid -s UUID -o value $BOOTPARTLOOP)"
RUUID="$(blkid -s UUID -o value /dev/${VGN}/root)"

# this has to come before packages:
cat > $MR/etc/fstab <<EOF
proc                    /proc     proc  defaults                  0  0
/dev/mapper/$VGN-root   /         $FSTYPE  noatime,errors=remount-ro 0  1
UUID=$BUUID             /boot     $FSTYPE  noatime                   0  2
none                    /tmp      tmpfs defaults                  0  0
none                    /var/tmp  tmpfs defaults                  0  0
EOF

cat > $MR/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

cat > $MR/etc/hosts <<EOF
127.0.0.1 localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

#### install and update packages

mount --bind /proc $MR/proc
mount --bind /dev $MR/dev
mount --bind /sys $MR/sys

# this file keeps stuff from starting up right now 
# when first installed in the chroot.
cat > $MR/usr/sbin/policy-rc.d <<EOF
#!/bin/bash
exit 101
EOF
chmod +x $MR/usr/sbin/policy-rc.d

# banish i386 forevermore, saucy
if [[ "$R" == "saucy" ]]; then
    chroot $MR dpkg --remove-architecture i386
fi

# i386 banishment for precise
if [[ -e $MR/etc/dpkg/dpkg.cfg.d/multiarch ]] ; then
    rm $MR/etc/dpkg/dpkg.cfg.d/multiarch
fi

chroot $MR <<EOF
export DEBIAN_FRONTEND=noninteractive
export RUNLEVEL=1
apt-get -y update

# acpid is to receive shutdown events from kvm
# accurate time (ntp) is essential for certificate verification to work 
# parted is to resize partitions on disk expansion
PACKAGES="
    linux-image-server
    lvm2
    acpid
    openssh-server
    ntp
    parted
    grub-pc
"
apt-get -y install \$PACKAGES
EOF

if [[ $WITHCHEF ]]; then
# install chef and ohai for provisioning later
chroot $MR <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive
export RUNLEVEL=1
apt-get install -y \
        ruby ruby-dev build-essential wget libruby rubygems
gem update --no-rdoc --no-ri
gem install ohai --no-rdoc --no-ri --verbose 
gem install chef --no-rdoc --no-ri --verbose
EOF
fi

chroot $MR <<EOF
grep -v ^server /etc/ntp.conf > /etc/ntp.conf.new
mv /etc/ntp.conf.new /etc/ntp.conf
EOF

# tell ntp not to try to sync to anything
# if an ntp server comes from the dhcp server then it will use that
cat >> $MR/etc/ntp.conf <<EOF
server 127.127.1.0
fudge 127.127.1.0 stratum 10
broadcastclient
EOF

# set some sane grub defaults for kvm guests
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"text serial=tty0 console=ttyS0\"" \
    >> $MR/etc/default/grub
# FIXME i think this is bogus, test changing it
echo "GRUB_SERIAL_COMMAND=\"serial --unit=0 --speed=9600 --stop=1\"" \
    >> $MR/etc/default/grub
if [[ "$R" == "saucy" ]]; then 
    echo "GRUB_TERMINAL=\"serial\"" >> $MR/etc/default/grub
fi
echo "GRUB_GFXPAYLOAD=\"text\"" >> $MR/etc/default/grub

# set root password (only useful at console, ssh password login is disabled)
chroot $MR /bin/bash -c "echo \"root:$ROOTPW\" | chpasswd"

chroot $MR grub-mkconfig -o /boot/grub/grub.cfg 2> /dev/null
cat > $MR/boot/grub/device.map <<EOF
(hd0)   ${LOOPDEV}
(hd0,1) ${BOOTPARTLOOP}
EOF
chroot $MR grub-install ${LOOPDEV} 2> /dev/null

# get rid of temporary device.map after grub is installed
rm $MR/boot/grub/device.map

# remove initramfs entirely:
chroot $MR update-initramfs -d -k all

# for some stupid reason, -k all doesn't work on gen after removing:
KERN="$(cd $MR/boot && ls vmlinuz*)"
VER="${KERN#vmlinuz-}"
chroot $MR update-initramfs -c -k $VER

# start a getty on the serial port for kvm console login
if [[ "$R" == "saucy" ]]; then 
cat > $MR/etc/init/ttyS0.conf <<EOF
# ttyS0 - getty
# run a getty on the serial console
start on stopped rc or RUNLEVEL=[12345]
stop on runlevel [!12345]
respawn
exec /sbin/getty -L 115200 ttyS0 vt102
EOF
fi

# update all packages on the system
chroot $MR /bin/bash -c \
    "DEBIAN_FRONTEND=noninteractive RUNLEVEL=1 apt-get -y upgrade"

# remove file that keeps installed stuff from starting up
rm $MR/usr/sbin/policy-rc.d

#####################################################
### Local Modifications
#####################################################

cat > $MR/etc/dhcp/dhclient-exit-hooks.d/hostname <<EOF
hostname \$new_host_name
EOF

# install ssh key
mkdir -p $MR/root/.ssh
cp "${KEYFILE}" $MR/root/.ssh/authorized_keys
chmod 600 $MR/root/.ssh/authorized_keys

# key auth only
echo "PasswordAuthentication no" >> $MR/etc/ssh/sshd_config
# in case dns is broken, don't lag logins
echo "UseDNS no" >> $MR/etc/ssh/sshd_config

# clean apt cache
rm $MR/var/cache/apt/archives/*.deb

# set dist apt source:
RPS="main restricted multiverse universe"
MURL="http://archive.ubuntu.com/ubuntu"
echo "deb $MURL $R $RPS" > $MR/etc/apt/sources.list
for P in updates backports security ; do
    echo "deb $MURL $R-$P $RPS" >> $MR/etc/apt/sources.list
done

# remove instance ssh host keys
rm $MR/etc/ssh/*key*
rm $MR/var/lib/dhcp/*.leases

# remove temporary resolver, dhcp will fix it:
rm $MR/etc/resolv.conf

# if there is an /etc/hostname then it won't
# pick up the right hostname from dhcp
test -e $MR/etc/hostname || rm $MR/etc/hostname

mkdir $MR/lib/eeqjvmtools

cat > $MR/lib/eeqjvmtools/expandroot.sh <<EOF
#!/bin/bash
parted -- /dev/vda resizepart 2 -1s
partprobe /dev/vda
pvresize /dev/vda2
lvresize -l +100%FREE /dev/vmvg0/root || true
resize2fs /dev/vmvg0/root
EOF
chmod +x $MR/lib/eeqjvmtools/expandroot.sh

# regenerate them on first boot
cat > $MR/etc/rc.local <<EOF
#!/bin/bash

# if no ssh host keys, generate them 
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server

# if the drive has gotten bigger since last time, grow the fs:
test -x /lib/eeqjvmtools/expandroot.sh && /lib/eeqjvmtools/expandroot.sh 

exit 0
EOF
chmod +x $MR/etc/rc.local

echo "******************************************************"
echo "*** Almost done.  Cleaning up..."
echo "******************************************************"

umount $MR/proc
umount $MR/sys

# udev insists on sticking around, kill it:
if [[ "$R" == "saucy" ]]; then
    fuser -m $MR -k
    sleep 1
fi
umount $MR/dev

if [[ $SAVESPACE ]]; then
    # zero space on boot:
    dd if=/dev/zero of=$MR/boot/zerofile bs=1M || true
    sync
    rm $MR/boot/zerofile
    # zero space on root
    dd if=/dev/zero of=$MR/zerofile bs=1M || true
    sync
    rm $MR/zerofile
fi

umount $MR/boot
umount $MR
sync

rmdir $MR

vgchange -a n $VGN
losetup -d $BOOTPARTLOOP
kpartx -dv $LOOPDEV
losetup -d $LOOPDEV
sync

OF="/tmp/${DATE}-${ORGNAME}-${R}64.qcow2"

qemu-img convert -f raw -O qcow2 $RI $OF && rm $RI
