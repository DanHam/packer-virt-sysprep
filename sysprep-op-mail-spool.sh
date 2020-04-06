#!/usr/bin/env bash
#
# Remove mail from the local mail spool
set -o errexit

mta_list=(
    "exim"
    "postfix"
    "sendmail"
)

mail_spool_locations=(
    "/var/spool/mail/*"
    "/var/mail/*"
)

# mail-spool: Remove email from the local mail spool directory
#     * /var/spool/mail/*
#     * /var/mail/*
echo "*** Removing any mail from the local mail spool"

# Best effort attempt to stop any MTA service
for mta in "${mta_list[@]}"
do
    # Systemd
    if command -v systemctl &>/dev/null ; then
        mta_service="$(systemctl list-units --type service | grep "${mta}" | \
                       cut -d' ' -f1)"
        if [ "x${mta_service}" != "x" ]; then
            if systemctl is-active "${mta_service}" &>/dev/null; then
                systemctl stop "${mta_service}"
            fi
        fi
    # Sys-v-init
    else
        mta_service="$(find /etc/init.d/ -iname "*${mta}*")"
        if [ "x${mta_service}" != "x" ]; then
            if ${mta_service} status | grep running &>/dev/null; then
                ${mta_service} stop
            fi
        fi
    fi
done


# Include hidden files in globs
shopt -s nullglob dotglob

# Remove any mail
# shellcheck disable=SC2068
for mail_spool in ${mail_spool_locations[@]}
do
    rm -rf "${mail_spool}"
done

exit 0
