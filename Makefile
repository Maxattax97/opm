.PHONY: test clean pool docker

all: opm pool test

opm:
	touch opm
	cat libopm.sh > opm
	echo "" >> opm
	printf "opm_cli \$$@" >> opm
	chmod +x opm

pool: pool.db.gz

pool.db.gz:
	bash ./buildPool.sh

test:
	cd test/ && sh ./posix.sh
	cd test/ && sh ./pass.sh
	# cd test/ && sh ./fail.sh

docker:
	sudo docker build -t opm_ubuntu -f docker/ubuntu/Dockerfile .
	sudo docker build -t opm_fedora -f docker/fedora/Dockerfile .
	sudo docker build -t opm_opensuse -f docker/opensuse/Dockerfile .
	sudo docker build -t opm_alpine -f docker/alpine/Dockerfile .

docker-test:
	sudo docker run opm_ubuntu /bin/sh -c "make test"
	sudo docker run opm_fedora /bin/sh -c "make test"
	sudo docker run opm_opensuse /bin/sh -c "make test"
	sudo docker run opm_alpine /bin/sh -c "make test"

clean:
	rm -f opm pool.db pool.db.gz
