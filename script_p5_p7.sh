#!/bin/bash
set -e
set -v

PKGS=("bird_168-1_amd64.deb" "net-tools_160+git20180626a.deb" "mysql-common_8032-1ubuntu2.deb" "libmysqlclient21_8032-1ubu.deb" "libsnmp35_58+dfsg-2ubuntu2.deb" "lldpd_104-1build2_amd64.deb" "bird-bgp_168-1_all.deb")

DIR=/media/

for t in ${PKGS[@]}; do
	dpkg --install $DIR$t || exit 1
done


SUDOGROUP=sudo
LOGINS=("d.alexeev" "s.ivannikov")
for u in ${LOGINS[@]}; do
	useradd -m -G $SUDOGROUP -p $u $u
	su $u -c 'ssh-keygen -t rsa -v'
done

