# KVM Ubuntu Image Builder

This is a Vagrant-based qcow2 image builder to build root images for
KVM/qemu.

Supports:

* Ubuntu 12.04 precise amd64
* Ubuntu 13.10 saucy amd64

# Assumptions

This will use whatever `~/.ssh/id_rsa.pub` is found on the host build system
as the `/root/.ssh/authorized_keys` inside the image being built.

The root password is set to 'root', but ssh password logins are disabled, so
it only works at the console.

The mirror in the image is set to `http://mirror.localservice/ubuntu`.  It
is expected that the VM environment you are using will make this resolve
appropriately and point at a local reverse proxy or full mirror.

# Requires

## Common

* curl 
* jq

## OSX

* Vagrant

## Linux

* root
* kpartx
* debootstrap
* lvm2
* qemu-utils

# todo

* support 12.04 (precise) or 12.10 (quantal) (chef server!)
* refactor local modifications/packages out of base build

# local changes todo

* remove whoopsie
* remove libwhoopsie0
* remove popcon / popularity-contest
* remove landscape stuff
* switch ssh to systemd invoked service
