YYYYMMDD := $(shell date +%Y%m%d)

default: gen

clean:
	rm -f *.bz2 *.qcow2 *.tmp authorized_keys

setup: clean
	./detect-mirror.sh > ubuntu-mirror.tmp
	cp $(HOME)/.ssh/id_rsa.pub ./authorized_keys

gen: setup
	./gen.sh

upload:
	rsync -avzP ./*.qcow2 \
		$(KVM_REMOTE_HOST):/storage/images/

sync: clean
	rsync -avP \
		--exclude=/.git		\
		--exclude=/.vagrant	\
		./					\
		$(KVM_REMOTE_HOST):/storage/buildimage/
