YYYYMMDD := $(shell date +%Y%m%d)

default: gen

clean:
	rm -f *.bz2 *.qcow2 *.tmp authorized_keys

setup: clean
	./detect-mirror.sh > ubuntu-mirror.tmp
	cp $(HOME)/.ssh/id_rsa.pub ./authorized_keys

gen: setup
	if [[ $$(uname) == "Darwin" ]]; then \
		vagrant destroy -f \
		vagrant up \
	else \
		export UBUNTU_MIRROR_URL="$(cat ./ubuntu-mirror.tmp)" \
		for D in precise saucy ; do \
			./buildimage.sh $D \
		done \
	fi

upload:
	rsync -azvP saucy64-$(YYYYMMDD).qcow2 \
		$(KVM_REMOTE_HOST):/storage/images/

sync:
	rsync -avP ./*.sh \
		$(KVM_REMOTE_HOST):/storage/buildimage/
