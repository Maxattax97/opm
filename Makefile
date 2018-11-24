.PHONY: test clean pool

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

clean:
	rm -f opm pool.db pool.db.gz
