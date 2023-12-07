#!/bin/sh

# In necessary, uncomment to add proxy
# echo "Acquire::https::Proxy \"http://PROXY_ENDPOINT\";" >> /etc/apt/apt.conf.d/proxy.conf
# echo "Acquire::http::Proxy \"http://PROXY_ENDPOINT\";" >> /etc/apt/apt.conf.d/proxy.conf
apt update
# Install fio with a timeout to wait for apt lock to be released
apt -y -o DPkg::Lock::Timeout=180 install fio