YYYYMMDD := $(shell date +%Y%m%d)

default: gen

clean:
	rm -f *.bz2 *.qcow2 *.tmp

gen: clean
	vagrant destroy -f
	vagrant up
	vagrant ssh-config > config.tmp
	scp -F ./config.tmp *.sh *.cfg default:
	vagrant ssh -c "sudo /bin/bash buildimage.sh"
	scp -F ./config.tmp default:/eeqj-saucy64/*.qcow2 ./eeqj-saucy64.qcow2
	pbzip2 eeqj-saucy64.qcow2

sync:
	rsync -avP ./*.sh \
		root@nue1d0.datavibe.net:/storage/buildimage/
