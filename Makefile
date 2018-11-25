.PHONY: test test-live clean pool docker production

all: clean opm pool test

opm:
	@echo "Packaging OPM for command line use ..."
	@touch opm
	@cat libopm.sh > opm
	@echo "" >> opm
	@printf "opm_cli \$$@" >> opm
	@chmod +x opm

pool: pool.db.gz

pool.db.gz:
	@echo "Building pool database ..."
	@bash ./buildPool.sh

production: clean opm pool
	@echo "Creating production files ..."
	@cp pool.db.gz production/
	@cp pool.db production/
	@cp libopm.sh production/
	@gzip -c -9 production/libopm.sh > production/libopm.sh.gz 
	@cp opm production/
	@gzip -c -9 production/opm > production/opm.gz 

test:
	@echo "Performing POSIX compliance tests ..."
	@cd test/ && sh ./posix.sh

test-live:
	@echo "Performing live tests ..."
	@cd test/ && sh ./live.sh

docker: all
	@echo "Building Docker images ..."
	@sudo docker build -t opm_ubuntu -f docker/ubuntu/Dockerfile .
	@sudo docker build -t opm_fedora -f docker/fedora/Dockerfile .
	@sudo docker build -t opm_opensuse -f docker/opensuse/Dockerfile .
	@# Disabled due to various errors:
	@# sudo docker build -t opm_alpine -f docker/alpine/Dockerfile .

docker-test:
	@echo "Testing Docker images ..."
	@sudo docker run opm_ubuntu /bin/sh -c "make test-live"
	@sudo docker run opm_fedora /bin/sh -c "make test-live"
	@sudo docker run opm_opensuse /bin/sh -c "make test-live"
	@# sudo docker run opm_alpine /bin/sh -c "make test-live"

travis-install: all
	@echo "Installing Travis CI environment for: ${TEST_SUITE} ..."
	@sudo docker build -t opm_${TEST_SUITE} -f docker/${TEST_SUITE}/Dockerfile .

travis-script:
	@echo "Testing on Travis CI for: ${TEST_SUITE} ..."
	@sudo docker run opm_${TEST_SUITE} /bin/sh -c "make test-live"

clean:
	@echo "Cleaning repository ..."
	@rm -f opm pool.db pool.db.gz
