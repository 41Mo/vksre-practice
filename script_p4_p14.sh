#!/bin/bash
set -e
set -v

DIR=/media/
PKGS=("bird_168-1_amd64.deb" "net-tools_160+git20180626a.deb" "mysql-community-client-plu.deb" "mysql-common_8032-1ubuntu2.deb" "libmysqlclient21_8032-1ubu.deb" "libsensors-config_360-2ubu.deb" "libsensors5_360-2ubuntu1_a.deb" "libsnmp-base_58+dfsg-2ubun.deb" "libsnmp35_58+dfsg-2ubuntu2.deb" "lldpd_104-1build2_amd64.deb" "bird-bgp_168-1_all.deb")
SUDOGROUP=sudo
LOGINS=("d.alexeev" "s.ivannikov")
ADMIN_USERNAME="admini"
LVVAR_SIZE="1G"
SWAP_SIZE_MB="4024"
CD_ROM_DEV="/dev/sr0"
PKGS_DIR="/media"
ALLOWED_SUBNET="192.168.0.0/16"
CONN_LIMIT="4096"

function install_pkgs() {
    if [! grep -qs "$PKGS_DIRP" /proc/mounts ]; then
        echo "mounting dir $PKGS_DIR"
        mount "$CD_ROM_DEV" "$PKGS_DIR"
    fi
    for t in "${PKGS[@]}"; do
        dpkg --install "$DIR$t" || exit 1
    done
}

function uninstall_pkgs() {
    for (( idx=${#PKGS[@]}-1 ; idx>=0 ; idx-- )) ; do
        dpkg --remove "$DIR${PKGS[idx]}"
    done
}

function create_users() {
    for u in "${LOGINS[@]}"; do
        useradd -m -G "$SUDOGROUP" -p "$u" "$u"
        su "$u" -c "ssh-keygen -t rsa -v"
        cp /home/"$u"/.ssh/id_rsa.pub /home/"$u"/.ssh/authorized_keys
        cp /home/"$u"/.ssh/id_rsa /home/"$ADMIN_USERNAME"/id_rsa_"$u"
        chown "$ADMIN_USERNAME:$ADMIN_USERNAME" /home/"$ADMIN_USERNAME"/id_rsa_"$u"
    done
}

function recreate_users() {
    for u in "${LOGINS[@]}"; do
        userdel -r "$u"
        useradd -m -G "$SUDOGROUP" -p "$u" "$u"
        su "$u" -c "ssh-keygen -t rsa -v"
        cp /home/"$u"/.ssh/id_rsa.pub /home/"$u"/.ssh/authorized_keys
        cp /home/"$u"/.ssh/id_rsa /home/"$ADMIN_USERNAME"/id_rsa_"$u"
        chown "$ADMIN_USERNAME:$ADMIN_USERNAME" /home/"$ADMIN_USERNAME"/id_rsa_"$u"
    done
}

function conf_lvVar() {
    lvcreate -L "$LVVAR_SIZE" -n lvVAR vgKVM
    mkfs.ext4 /dev/mapper/vgKVM-lvVAR
    echo "/dev/mapper/vgKVM-lvVAR /var ext4 defaults 0 1" >> /etc/fstab
}

function conf_swap() {
    dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_SIZE_MB"
    chmod 0600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap defaults 0 0" >> /etc/fstab
}

function conf_iptables() {
    iptables -F
    iptables -X
    iptables -A INPUT -p icmp --icmp-type echo-request -j REJECT --reject-with icmp-port-unreachable
    # iptables -A OUTPUT -p icmp --icmp-type echo-reply -j DROP
    iptables -A INPUT -s "$ALLOWED_SUBNET" -j ACCEPT
    iptables -A INPUT -j DROP
    iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -m connlimit --connlimit-above "$CONN_LIMIT" -j DROP
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
}

function conf_sshd() {
    read -p "Warning: This script will disable root login and password authentication in SSH. Are you sure you want to continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then

        SSHD_CONF="/etc/ssh/sshd_config"
        cp "$SSHD_CONF" "$SSHD_CONF".bak

        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/g' "$SSHD_CONF"
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/g' "$SSHD_CONF"

        systemctl restart sshd.service
    else
        echo "Skipped sshd configuration"
    fi
}

function conf_iptables_persistence() {
    echo "
[Unit]
Description=Load iptables rules on boot

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
ExecReload=/sbin/iptables-restore /etc/iptables/rules.v4

[Install]
WantedBy=multi-user.target
    " >> /etc/systemd/system/iptables_persistence.service
    systemctl daemon-reload
    sudo systemctl enable --now iptables_persistence.service
}

function conf_kmodules() {
    KMODULES=("nf_conntrack" "nf_conntrack_netlink" "xt_connlimit")
    MODLPATH="/etc/modules-load.d"
    mkdir -p "$MODLPATH"

    for m in "${KMODULES[@]}"; do
        modprobe "$m"
        echo "$m" >> "$MODLPATH/netfilter.conf"
    done

}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --install_pkgs )
            install_pkgs ;;
        --create_users)
            create_users ;;
        --recreate_users)
            recreate_users ;;
        --lvcreate )
            conf_lvVar ;;
        --swap)
            conf_swap ;;
        --iptables )
            conf_iptables
            conf_iptables_persistence
            ;;
        --netfilter )
            conf_kmodules ;;
        --configure_sshd )
            conf_sshd ;;
        --all-sequentially )
            install_pkgs
            create_users
            conf_lvVar
            conf_swap
            conf_iptables
            conf_iptables_persistence
            conf_kmodules
            conf_sshd
            ;;

        * ) echo "Unknown option $key" ;;
    esac
    shift
done
