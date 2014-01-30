# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

SETUP_BASE = <<-EOF

echo "UseDNS no" >> /etc/ssh/sshd_config
service ssh restart

function detect_local_mirror () {
    AL="$(avahi-browse -p -t -r _ubuntumirror._tcp | grep '^=' | head -1)"
    if [ -n "$AL" ]; then
        NAME="$(echo \"$AL\" | cut -d';' -f 8)"
        PORT="$(echo \"$AL\" | cut -d';' -f 9)"
        UM="http://${NAME}:${PORT}/ubuntu/"
        MOK="$(curl --head \"${UM}ls-lR.gz\" 2>&1 | grep '200 OK' | wc -l)"
        if [ $MOK -gt 0 ]; then
            echo "$UM"
        fi
    fi
}

function set_apt_mirror () {
    CN="$(lsb_release -c -s)"
    RPS="main restricted multiverse universe"
    echo "deb $1 $CN $RPS" > /etc/apt/sources.list.new
    for P in updates backports security ; do
        echo "deb $1 $CN-$P $RPS" >> /etc/apt/sources.list.new
    done
    mv /etc/apt/sources.list.new /etc/apt/sources.list
}


set_apt_mirror "mirror://mirrors.ubuntu.com/mirrors.txt"
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
apt-get -y install kpartx debootstrap lvm2 qemu-utils 
EOF


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu-12.04"
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/precise/" + \
    "current/precise-server-cloudimg-amd64-vagrant-disk1.box"
  config.vm.network "public_network", :bridge => "en4: Display Ethernet"
  config.vm.provision "shell", inline: SETUP_BASE
  config.vm.provision "shell", path: "buildimage.sh"
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end
end
