#!/bin/bash
# set -e
# set -x

BASE_DIR="/var/log"

HOSTDIR="$BASE_DIR"
REMOTE_DIR="$BASE_DIR"
REMOTE_USER="admini"
REMOTE_IP="192.168.122.141"
HOST_USER="admini"
REMOTE="$REMOTE_USER@$REMOTE_IP"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

FILES_OLDER_THAN_DAYS="7"
NFILES=10
NBYTES_PER_FILE=100

#               minute hour day_of_month month day_of_week
CRON_RULE_PUSH="*/2      *         *       *        * "
CRON_RULE_DEL="*/1      *         *       *        * "

# 1 <=> true; 0 <=> false

# change MTIME of created files to MODTIMETO.
CHANGEMTIME=1
MODTIMETO="8 days ago"

# run in headless mode, dont ask user anything
HEADLESS=1

# dry run mode. Dont delete any data
DRY_RUN=0
# cleanup generated date on host after push
CLEAN_HOST_AFTER_PUSH=0


function remove_old_files() {
    use_ssh=${1:-1}
    findcmd="find $REMOTE_DIR/* -prune -name \"file_*.dat\" -type f -mtime +$FILES_OLDER_THAN_DAYS"
    sshcmd="ssh $REMOTE -i $SSH_KEY_PATH"

    if [ "$DRY_RUN" -eq 1 ]; then
        eval "$sshcmd '$findcmd -exec ls {} \\;'"
    else
        eval "$sshcmd '$findcmd -exec rm {} \\;'"
    fi

    echo "$(date) cleanup"
}

function generate_data() {
    if [ ! -d "$HOSTDIR" ]; then

        if [ "$HEADLESS" -eq 1 ]; then
            echo "$HOSTDIR doesnt exists."
            return -1
        fi

        read -p "$HOSTDIR doesnt exists. Create? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo mkdir -p "$HOSTDIR"
            sudo chown "$REMOTE_USER:$REMOTE_USER" "$HOSTDIR"
        fi
    fi

    var=$RANDOM
    for (( i=$var; i<$(( $var + $NFILES )); i++ ))
    do
        file="$HOSTDIR/file_$i.dat"
        head -c 100 /dev/random >> "$file"

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

    echo """$(date) pushed to remote"
}

function configure_remote() {
    grp=$(ssh -i "$SSH_KEY_PATH" "$REMOTE" stat -c "%G" "$BASE_DIR")

    read -p  "add ""$REMOTE to group ""$grp? (y/n)" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        ssh -i """$SSH_KEY_PATH" """$REMOTE" "sudo -S usermod -a -G ""$grp ""$REMOTE_USER"
    fi

    read -p  "configure ""$REMOTE:$BASE_DIR to allow group rw access? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        ssh -i """$SSH_KEY_PATH" """$REMOTE" "sudo -S chmod g+rw ""$BASE_DIR"
    fi
}

function configure_host() {
    grp=$(stat -c "%G" "$BASE_DIR")
    read -p  "configure HOST ""$BASE_DIR to allow group rw access? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        sudo chmod g+rw """$BASE_DIR"
    fi
    this_script=""${BASH_SOURCE[0]}
    sudo cp """$this_script" /usr/local/bin/
    bin_script=/usr/local/bin/""$(basename "$0")
    sudo chown """$HOST_USER:""$HOST_USER" """$bin_script"
    sudo chmod 770 """$bin_script"

    echo """${CRON_RULE_PUSH}root sudo -u ""$HOST_USER -g ""$grp ""$bin_script --gen_data --push > /var/log/at_push.log 2>&1" | sudo tee /etc/cron.d/astersik_task_push
    echo """${CRON_RULE_DEL}root sudo -u ""$HOST_USER -g ""$grp ""$bin_script --distclean > /var/log/at_del.log 2>&1" | sudo tee /etc/cron.d/astersik_task_del
}

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --remove_old_files )
            remove_old_files
            ;;
        --gen_data )
            generate_data
            ;;
        * )
            echo "Unknown option $key"
            exit 1
            ;;
    esac
    shift
done
