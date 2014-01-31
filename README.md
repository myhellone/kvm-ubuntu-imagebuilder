# KVM Ubuntu Image Builder

This is a Vagrant-based qcow2 image builder
to build Ubuntu 13.10 (saucy) root images to boot under
KVM/qemu virtualization.

# todo

* support 12.04 (precise) or 12.10 (quantal) (chef server!)
* refactor local modifications/packages out of base build

# local changes todo

* remove whoopsie
* remove libwhoopsie0
* remove popcon / popularity-contest
* remove landscape stuff
* switch ssh to systemd invoked service
