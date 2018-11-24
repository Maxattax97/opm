FROM opensuse

WORKDIR /home/app/

RUN zypper ref 
RUN zypper in -y make 

COPY . /home/app/
