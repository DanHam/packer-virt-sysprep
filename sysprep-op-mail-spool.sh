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

# Best effort attempt to stop any MTA service
for mta in ${mta_list[@]}
do
    # Systemd
    if [ $(command -v systemctl) ]; then
        mta_service="$(systemctl list-units --type service | grep ${mta} | \
                       cut -d' ' -f1)"
        if [ "x${mta_service}" != "x" ]; then
            if [ "$(systemctl is-active ${mta_service})" = "active" ]; then
                systemctl stop ${mta_service}
            fi
        fi
    # Sys-v-init
    else
        mta_service="$(find /etc/init.d/ -iname "*${mta}*")"
        if [ "x${mta_service}" != "x" ]; then
            if [ "x$(${mta_service} status | grep running)" != "x" ]; then
                ${mta_service} stop >/dev/null
            fi
        fi
    fi
done


# Include hidden files in globs
shopt -s nullglob dotglob

# Remove any mail
for mail_spool in ${mail_spool_locations[@]}
do
    rm -rf ${mail_spool}
done

exit 0
