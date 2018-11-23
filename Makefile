all: opm

opm:
	touch opm
	cat libopm.sh > opm
	echo "" >> opm
	printf "opm_cli \$$@" >> opm
	chmod +x opm

clean:
	rm -f opm
