#!/bin/bash

# install docker from dev script
# https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script
if ! type "docker" > /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh ./get-docker.sh
  rm get-docker.sh
fi

# install docker-compose
# https://docs.docker.com/compose/install/#install-compose-on-linux-systems
if ! type "docker-compose" > /dev/null; then
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# authenticate with gcloud:
sudo gcloud auth activate-service-account --key-file=/tmp/pluribus.json
sudo gcloud auth configure-docker

# Allow ssh root login
sudo sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config

# pull public images
sudo docker pull rabbitmq:management
sudo docker pull jaegertracing/all-in-one
sudo docker pull redis
sudo docker pull mongo

# install some extras
sudo apt-get install -y --no-install-recommends \
    rsync \
    less \
    vim \
    htop \
    tree \
    ;

# Clean image
sudo apt-get clean
sudo apt-get autoclean
