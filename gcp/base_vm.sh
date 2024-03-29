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
sudo gcloud auth activate-service-account --key-file=/tmp/credentials.json
sudo gcloud auth -q configure-docker

# pull public images
sudo docker pull rabbitmq:management
sudo docker pull jaegertracing/all-in-one
sudo docker pull redis
sudo docker pull mongo:5.0.10

# install some extras
sudo apt-get install -y --no-install-recommends \
    rsync \
    less \
    vim \
    htop \
    iftop \
    nload \
    tree \
    tmux \
    ;

# Clean image
sudo apt-get clean
sudo apt-get autoclean

# Allow ssh root login
sudo sed -i 's/PermitRootLogin no/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
# add key to roots authorized_keys
echo "# Added by Antipode@TrainTicket" | sudo tee --append /root/.ssh/authorized_keys
cat /tmp/google_compute_engine.pub | sudo tee --append /root/.ssh/authorized_keys
# reload ssh
sudo systemctl reload ssh

# Disable Nagle's Algorithm
sudo sysctl -w net.ipv4.tcp_syncookies=1
sudo sysctl -w net.ipv4.tcp_synack_retries=1
sudo sysctl -w net.ipv4.tcp_syn_retries=1
sudo sysctl -w net.core.somaxconn=4096