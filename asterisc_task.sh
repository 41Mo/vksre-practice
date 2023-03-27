#!/bin/bash
set -e
#set -x

HOSTDIR="/var/log/test_dir"
REMOTE_DIR="/var/log/test_dir"

REMOTE="admini@192.168.122.44"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"

FILES_OLDER_THAN_DAYS="7"
NFILES=5
NBYTES_PER_FILE=100

# change MTIME of created files to MODTIMETO.
CHANGEMTIME=1
MODTIMETO="8 days ago"

# run in headless mode, dont ask user anything
HEADLESS=1

# dry run mode. Dont delete any data
DRY_RUN=0


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
            return -1
        fi

        read -p "$HOSTDIR doesnt exists. Create? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo mkdir -p "$HOSTDIR"
            sudo chown admini:admini "$HOSTDIR"
        fi

    fi
    for (( i=0; i<$(( $NFILES - 1 )); i++ ))
    do
        file="$HOSTDIR/file_$i.dat"
        head -c 100 /dev/random >> "$file"

        if [ $(($i % 2)) -eq 0 ] && [ "$CHANGEMTIME" -eq 1 ]; then
            touch -d "$MODTIMETO" "$file"
        fi

    done
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
