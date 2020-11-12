#!/bin/bash

# clean all
yum update -y
yum clean all


# Install vagrant default key (make sure if it's your key, not mine)
mkdir -pm 700 /home/vagrant/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQoFyol3Kba0jpAUFVwE/mZNR17VCBXeFM+WX7yT7kb vagrant EC key" > /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh


# Remove temporary files
rm -rf /tmp/*
rm  -f /var/log/wtmp /var/log/btmp
rm -rf /var/cache/* /usr/share/doc/*
rm -rf /var/cache/yum
rm -rf /vagrant/home/*.iso
rm  -f ~/.bash_history
history -c

rm -rf /run/log/journal/*

# Fill zeros all empty space
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
sync
grub2-set-default 0
echo "###   Hi from secone stage" >> /boot/grub2/grub.cfg
