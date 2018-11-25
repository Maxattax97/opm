FROM ubuntu

WORKDIR /home/app/

RUN apt-get update
# Would prefer to not install sudo, but currently needed.
RUN apt-get install -y sudo make 

COPY . /home/app/
