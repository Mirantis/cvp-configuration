#!/bin/bash
cd /artifacts
# Installing prerequisites
apt -y update
export TZ="America/Chicago"
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
apt -y install python3-pip vim git iperf3 mtr htop iputils-ping traceroute tcpdump wget iproute2 curl
pip3 install python-openstackclient python-neutronclient python-heatclient pyghmi python-octaviaclient

mkdir /artifacts/cmp-check && cd /artifacts/cmp-check
cp /artifacts/res-files/scripts/prepare.sh ./
cp /artifacts/res-files/scripts/cmp_check.sh ./
cp /artifacts/res-files/cleanup.sh ./
