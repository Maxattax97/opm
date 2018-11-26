.PHONY: test test-live clean pool docker production lint

all: clean opm pool test

opm:
	@echo "Packaging OPM for command line use ..."
	@cd scripts/ && bash ./buildCli.sh

pool: pool.db.gz

pool.db.gz:
	@echo "Building pool database ..."
	@cd scripts/ && bash ./buildPool.sh

production: clean opm pool
	@echo "Creating production files ..."
	@cp pool.db.gz production/
	@cp pool.db production/
	@cp libopm.sh production/
	@gzip -c -9 production/libopm.sh > production/libopm.sh.gz 
	@echo "Minifying OPM CLI ..."
	@cd scripts/ && perl ./minify.pl -i ../opm -o ../opm.min -V OpM -C -F
	@mv opm.min production/opm
	@chmod +x production/opm
	@gzip -c -9 production/opm > production/opm.gz 

lint:
	@shellcheck --shell=sh libopm.sh

test:
	@echo "Performing POSIX compliance tests ..."
	@cd test/ && sh ./posix.sh
	@echo "Performing command line tests ..."
	@cd test/ && sh ./cli.sh

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
