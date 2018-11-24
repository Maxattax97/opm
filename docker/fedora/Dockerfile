FROM fedora 

WORKDIR /home/app/

# Would prefer to not install findutils (for xargs), but currently needed for shUnit2.
RUN dnf install -y make findutils

COPY . /home/app/
