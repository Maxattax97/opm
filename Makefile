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
	cd test/ && bash ./posix.sh
	cd test/ && bash ./pass.sh
	cd test/ && bash ./fail.sh

docker:
	docker build -t opm_ubuntu -f docker/ubuntu/Dockerfile .

docker-test:
	docker run opm_ubuntu /bin/sh -c "make clean opm pool test"

docker-clean:
	docker rm

clean:
	rm -f opm pool.db pool.db.gz
