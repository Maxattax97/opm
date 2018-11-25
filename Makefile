.PHONY: test test-live clean pool docker production

all: clean opm pool test

opm:
	touch opm
	cat libopm.sh > opm
	echo "" >> opm
	printf "opm_cli \$$@" >> opm
	chmod +x opm

pool: pool.db.gz

pool.db.gz:
	bash ./buildPool.sh

production: clean opm pool
	cp pool.db.gz production/
	cp pool.db production/
	cp libopm.sh production/
	gzip -c -9 production/libopm.sh > production/libopm.sh.gz 
	cp opm production/
	gzip -c -9 production/opm > production/opm.gz 

test:
	cd test/ && sh ./posix.sh

test-live:
	cd test/ && sh ./live.sh

docker: all
	sudo docker build -t opm_ubuntu -f docker/ubuntu/Dockerfile .
	sudo docker build -t opm_fedora -f docker/fedora/Dockerfile .
	sudo docker build -t opm_opensuse -f docker/opensuse/Dockerfile .
	# Disabled due to various errors:
	# sudo docker build -t opm_alpine -f docker/alpine/Dockerfile .

docker-test:
	sudo docker run opm_ubuntu /bin/sh -c "make test-live"
	sudo docker run opm_fedora /bin/sh -c "make test-live"
	sudo docker run opm_opensuse /bin/sh -c "make test-live"
	# sudo docker run opm_alpine /bin/sh -c "make test-live"

clean:
	rm -f opm pool.db pool.db.gz
