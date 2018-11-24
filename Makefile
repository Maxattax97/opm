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
	docker build -t opm_ubuntu -f docker/ubuntu/Dockerfile .
	docker build -t opm_fedora -f docker/fedora/Dockerfile .
	docker build -t opm_opensuse -f docker/opensuse/Dockerfile .
	docker build -t opm_alpine -f docker/alpine/Dockerfile .

docker-test:
	docker run opm_ubuntu /bin/sh -c "make test"
	docker run opm_fedora /bin/sh -c "make test"
	docker run opm_opensuse /bin/sh -c "make test"
	docker run opm_alpine /bin/sh -c "make test"

docker-clean:
	docker rm

clean:
	rm -f opm pool.db pool.db.gz
