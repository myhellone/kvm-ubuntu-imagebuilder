# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "opscode-ubuntu-13.10"
  config.vm.box_url = 'https://opscode-vm-bento.s3.amazonaws.com/vagrant/' + \
    'virtualbox/opscode_ubuntu-13.10_provisionerless.box'
  config.vm.network "public_network", :bridge => "en4: Display Ethernet"
  config.vm.provision "shell", path: "prepvagrant.sh"
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "3000"]
  end
end
