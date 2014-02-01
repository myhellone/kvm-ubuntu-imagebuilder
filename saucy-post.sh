#!/bin/bash

set -e
set -v
set -x

MR="$1"

# disable apt installation exuberance
cat > $MR/etc/apt/apt.conf.d/99-vm-no-extras-please <<EOF
APT::Install-Recommends "false";
APT::Install-Suggest "false";
EOF

cat > $MR/etc/environment <<EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LANGUAGE="en_US:en"
LANG="en_US.UTF-8"
ROOT_IMAGE_BUILD_DATE="$DATE"
EOF

chroot $MR locale-gen en_US.UTF-8
chroot $MR dpkg-reconfigure locales

#echo 'cd /dev && MAKEDEV generic 2>/dev/null' | chroot $MR 

#BUUID="$(blkid -s UUID -o value /dev/mapper/${LDBASE}p1)"
#RUUID="$(blkid -s UUID -o value /dev/${VGN}/root)"

# this has to come before packages:
#cat > $MR/etc/fstab <<EOF
#proc                    /proc     proc  defaults                  0  0
#/dev/mapper/$VGN-root   /         ext4  noatime,errors=remount-ro 0  1
#UUID=$BUUID             /boot     ext4  noatime                   0  2
#none                    /tmp      tmpfs defaults                  0  0
#none                    /var/tmp  tmpfs defaults                  0  0
#EOF

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

cat > $MR/usr/sbin/policy-rc.d <<EOF
#!/bin/bash
exit 101
EOF
chmod +x $MR/usr/sbin/policy-rc.d

# install chef and ohai for provisioning later
chroot $MR env /bin/bash <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive
export RUNLEVEL=1
export HOME=/
apt-get update
apt-get install -y \
        ruby ruby-dev build-essential wget libruby rubygems
gem update --no-rdoc --no-ri
gem install ohai --no-rdoc --no-ri --verbose 
gem install chef --no-rdoc --no-ri --verbose
EOF

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
#echo "GRUB_SERIAL_COMMAND=\"serial --unit=0 --speed=9600 --stop=1\"" \
#    >> $MR/etc/default/grub
echo "GRUB_TERMINAL=\"serial\"" >> $MR/etc/default/grub
echo "GRUB_GFXPAYLOAD=\"text\"" >> $MR/etc/default/grub

# generate grub configs and install it to the generated blockdev
chroot $MR update-grub 2> /dev/null
chroot $MR grub-mkconfig -o /boot/grub/grub.cfg 2> /dev/null

# start a getty on the serial port for kvm console login
cat > $MR/etc/init/ttyS0.conf <<EOF
# ttyS0 - getty
# run a getty on the serial console
start on stopped rc or RUNLEVEL=[12345]
stop on runlevel [!12345]
respawn
exec /sbin/getty -L 115200 ttyS0 vt102
EOF

# disable multiarch, banish i386 forevermore
chroot $MR dpkg --remove-architecture i386

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

SK=""
SK+="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2BRNjtz7nqobJQqDtiXhcX6sgN"
SK+="TiPLAFEGHDL0QbCFFWt1HTWsvE6t3Z6UkhKszAaVfwFDIChL3KGrpGpoS24sFP"
SK+="qMe+d5FGGbgeSv0527G8tE4HZqQRrWS5rwZz+VgGBskWD32imZwKZpOICM74Lr"
SK+="rR9v7DZrRDXFSTql4oWJvPwm2pvkMrCbi9o61VexJ3hXIuI8mFbwZ0EoF5mQ60"
SK+="MMt8Yw/d4AqFr/eC3wUsWPDLQ2Tiz2Y2WoPfklD6uBNBXxUdjO/oIF9WBuRxuc"
SK+="Fh5LIWnkm08bJY7+QlVUEdOL5GqJQademufnz+zzYyIr9l9YjGkD1DQWtskv6v"
SK+="Jbl7HQ== sneak@ganymede"

mkdir -p $MR/root/.ssh/
echo "$SK" > $MR/root/.ssh/authorized_keys

echo "PasswordAuthentication no" >> $MR/etc/ssh/sshd_config
echo "UseDNS no" >> $MR/etc/ssh/sshd_config

# clean apt cache
rm $MR/var/cache/apt/archives/*.deb
rm $MR/var/lib/apt/lists/*saucy*

# remove instance ssh host keys
rm $MR/etc/ssh/*key*
rm $MR/var/lib/dhcp/*.leases

# remove temporary resolver, dhcp will fix it:
rm $MR/etc/resolv.conf

# if there is an /etc/hostname then it won't
# pick up the right hostname from dhcp
test -e $MR/etc/hostname || rm $MR/etc/hostname

#mkdir $MR/lib/eeqjvmtools

#cat > $MR/lib/eeqjvmtools/expandroot.sh <<EOF
##!/bin/bash
#parted -- /dev/vda resizepart 2 -1s
#partprobe /dev/vda
#pvresize /dev/vda2
#lvresize -l +100%FREE /dev/vmvg0/root || true
#resize2fs /dev/vmvg0/root
#EOF
#chmod +x $MR/lib/eeqjvmtools/expandroot.sh

# regenerate them on first boot
cat > $MR/etc/rc.local <<EOF
#!/bin/bash

# if no ssh host keys, generate them 
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server

# if the drive has gotten bigger since last time, grow the fs:
#/lib/eeqjvmtools/expandroot.sh 

exit 0
EOF
chmod +x $MR/etc/rc.local

# zero space on root:
dd if=/dev/zero of=$MR/zerofile bs=10M || true
rm $MR/zerofile
