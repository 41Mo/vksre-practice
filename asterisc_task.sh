#!/bin/bash
# set -e
# set -x

BASE_DIR="/var/log"

HOSTDIR="$BASE_DIR"
REMOTE_DIR="$BASE_DIR/test_sync"
REMOTE_USER="admini"
REMOTE_IP="192.168.122.141"
HOST_USER="admini"
REMOTE="$REMOTE_USER@$REMOTE_IP"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

FILES_OLDER_THAN_DAYS="7"
NFILES=5
NBYTES_PER_FILE=100

#               minute hour day_of_month month day_of_week
CRON_RULE_PUSH="*/1      *         *       *        * "

# 1 <=> true; 0 <=> false

# change MTIME of created files to MODTIMETO.
RANDOMFILENAMES=1
CHANGEMTIME=1
MODTIMETO="8 days ago"

# cleanup generated data on host after push
CLEAN_HOST_AFTER_PUSH=1


function remove_old_files() {
    use_ssh=${1:-1}

    sshcmd='ssh '$REMOTE' -i '$SSH_KEY_PATH''
    folderthan='-mtime +'$FILES_OLDER_THAN_DAYS''
    direc="$REMOTE_DIR"
    if [ "$use_ssh" -eq 0 ]; then
        folderthan=""
        direc="$HOSTDIR"
        cd "$HOSTDIR"
    fi
    findcmd='find '$direc'/* -prune -name "file_*.dat" -type f '$folderthan''

    if [ "$use_ssh" -eq 1 ]; then
        eval ' '"$sshcmd"'  '\''' "$findcmd"' -exec rm {} \; '\'' '
    else
        eval ' '"$findcmd"' -exec rm {} \; '
    fi

    echo "$(date) cleanup"
}

function generate_data() {
    if [ "$RANDOMFILENAMES" -eq 1 ]; then
        var=$RANDOM
    else
        var=0
    fi
    for (( i=$var; i<$(( $var + $NFILES )); i++ ))
    do
        file="$HOSTDIR/file_$i.dat"
        head -c 100 /dev/random > "$file"

        if [ $(($i % 2)) -eq 0 ] && [ "$CHANGEMTIME" -eq 1 ]; then
            touch -d "$MODTIMETO" "$file"
        fi

    done

    echo "$(date) generated_data"

}

function push_files_to_remote() {
    scp -p "$HOSTDIR"/file_*.dat "$REMOTE:$REMOTE_DIR/"

    if [[ $CLEAN_HOST_AFTER_PUSH -eq 1 ]]; then
        remove_old_files 0
    fi

    echo "$(date) pushed to remote"
}

function configure_remote() {

    remote_check='
    DIR='"$REMOTE_DIR"'
    # Loop through parent directories until root directory is reached
    while [ "$DIR" != "/" ]; do
        if [ -d "$DIR" ]; then
            # Directory exists, break out of loop
            break
        else
            # Directory does not exist, move up one level
            DIR=$(dirname "$DIR")
        fi
    done
    echo "$DIR"
    '

    d=$(ssh -i "$SSH_KEY_PATH" "$REMOTE" "bash -c '$remote_check'")
    g=$(ssh -i "$SSH_KEY_PATH" "$REMOTE" stat -c "%G" "$d")
    u=$(ssh -i "$SSH_KEY_PATH" "$REMOTE" stat -c "%U" "$d")

    ssh -i "$SSH_KEY_PATH" "$REMOTE" "sudo -S mkdir -p $REMOTE_DIR"
    ssh -i "$SSH_KEY_PATH" "$REMOTE" "sudo -S chown $u:$g $REMOTE_DIR"
    ssh -i "$SSH_KEY_PATH" "$REMOTE" "sudo -S chmod 775 $REMOTE_DIR"

    grp=$(ssh -i "$SSH_KEY_PATH" "$REMOTE" stat -c "%G" "$REMOTE_DIR")

    read -p  "add $REMOTE to group $grp? (y/n)" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        ssh -i "$SSH_KEY_PATH" "$REMOTE" "sudo -S usermod -a -G $grp $REMOTE_USER"
    fi

    read -p  "configure $REMOTE:$REMOTE_DIR to allow group rw access? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        ssh -i "$SSH_KEY_PATH" "$REMOTE" "sudo -S chmod g+rw $REMOTE_DIR"
    fi
}

function configure_host() {

    if [ ! -d "$HOSTDIR" ]; then
        read -p "$HOSTDIR doesnt exists. Create? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo mkdir -p "$HOSTDIR"
            sudo chown "$HOST_USER:$HOST_USER" "$HOSTDIR"
        fi
    fi

    grp=$(stat -c "%G" "$HOSTDIR")
    read -p  "configure HOST $HOSTDIR to allow group rw access? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        sudo chmod g+rw "$HOSTDIR"
    fi
    this_script=${BASH_SOURCE[0]}
    sudo cp "$this_script" /usr/local/bin/
    bin_script=/usr/local/bin/$(basename "$0")
    sudo chown "$HOST_USER:$HOST_USER" "$bin_script"
    sudo chmod 770 "$bin_script"

    echo "${CRON_RULE_PUSH}root sudo -u $HOST_USER -g $grp $bin_script --gen_data --push --distclean > /var/log/at.log 2>&1" | sudo tee /etc/cron.d/astersik_task
}

while [[ $# -gt 0 ]]
do
    key=$1
    case $key in
        --distclean )
            remove_old_files
            ;;
        --push )
            push_files_to_remote
            ;;
        --gen_data )
            generate_data
            ;;
        --configure )
            configure_host
            configure_remote
            ;;
        * )
            echo "Unknown option $key"
            exit 1
            ;;
    esac
    shift
done
