# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

SETUP_BASE = <<-EOF
#!/bin/bash
set -e

# byobu lags login in this vm for some reason?
test -e /etc/profile.d/Z97-byobu.sh && rm /etc/profile.d/Z97-byobu.sh

echo "UseDNS no" >> /etc/ssh/sshd_config
service ssh restart

echo "exec sudo -i" >> /home/vagrant/.bashrc

function set_apt_mirror () {
    CN="$(lsb_release -c -s)"
    RPS="main restricted multiverse universe"
    echo "deb $1 $CN $RPS" > /etc/apt/sources.list.new
    for P in updates backports security ; do
        echo "deb $1 $CN-$P $RPS" >> /etc/apt/sources.list.new
    done
    mv /etc/apt/sources.list.new /etc/apt/sources.list
}

export UBUNTU_MIRROR_URL="`cat /vagrant/ubuntu-mirror.tmp`"

if [[ ! -z "$UBUNTU_MIRROR_URL" ]]; then
    set_apt_mirror "$UBUNTU_MIRROR_URL"
fi

if [[ "$(lsb_release -s -c)" == "saucy" ]]; then
    dpkg --remove-architecture i386
else
    rm /etc/dpkg/dpkg.cfg.d/multiarch
fi
apt-get update
apt-get -y install kpartx debootstrap lvm2 qemu-utils 

DISTS="precise saucy"

for DIST in $DISTS; do
    export KEYFILE="/vagrant/authorized_keys"
    /vagrant/buildimage.sh $DIST || exit $?
    mv /tmp/*64.qcow2 /vagrant/
    exit 0 # FIXME
done

EOF

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu-12.04"
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/precise/" + \
    "current/precise-server-cloudimg-amd64-vagrant-disk1.box"
  config.cache.auto_detect = true if Vagrant.has_plugin?("vagrant-cachier")

  # bridge to my actual local lan instead of the private vagrant
  # network so that avahi discover will work right to find my mirror
  # osx requires it to be the full descriptive name, mine is e.g.
  # "en4: Display Ethernet" (tb display wired ethernet)
  if ENV['VAGRANT_BRIDGE_DEVICE']
    config.vm.network "public_network",
      :bridge => ENV['VAGRANT_BRIDGE_DEVICE']
  end

  config.vm.provision "shell", inline: SETUP_BASE
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end
end
