YYYYMMDD := $(shell date +%Y%m%d)

default: gen

clean:
	rm -f *.bz2 *.qcow2

gen: clean
	vagrant destroy -f
	vagrant up
	vagrant ssh -- cat saucy64.qcow2 | pv > .tmp.qcow2
	mv .tmp.qcow2 saucy64-$(YYYYMMDD).qcow2
	rsync -azvP saucy64-$(YYYYMMDD).qcow2 \
		root@nue1d0.datavibe.net:/storage/images/

sync:
	rsync -avP ./*.sh \
		root@nue1d0.datavibe.net:/storage/buildimage/
