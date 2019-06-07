# package
apt-get install qemu-utils

#image
wget https://cloud-images.ubuntu.com/releases/14.04.1/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img

# adding module
modprobe nbd
dmesg | grep nbd

# mapping it
qemu-nbd --connect=/dev/nbd0 /home/osavatieiev/ubuntu-14.04-server-cloudimg-amd64-disk1.img
blockdev --rereadpt /dev/nbd0
mkdir /mnt/target_vm
mount /dev/nbd0p1 /mnt/target_vm

# download iperf just in case
wget http://archive.ubuntu.com/ubuntu/pool/universe/i/iperf/iperf_2.0.5-3_amd64.deb
cp iperf_2.0.5-3_amd64.deb /mnt/vm/tmp/

chroot /mnt/target_vm/

# add user
adduser spt
usermod -aG sudo spt
dpkg -i /tmp/iperf_2.0.5-3_amd64.deb

# ctrl + D
# disconect
umount /mnt/target_vm
qemu-nbd --disconnect /dev/nbd0