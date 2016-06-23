#!/usr/bin/env bash
#
# Remove mail from the local mail spool

MTA_LIST=(
    "exim"
    "postfix"
    "sendmail"
)

MAIL_SPOOL_LOCATIONS=(
    "/var/spool/mail/*"
    "/var/mail/*"
)

# Best effort attempt to stop any MTA service
for MTA in ${MTA_LIST[@]}
do
    # Systemd
    if [ $(command -v systemctl) ]; then
        SERVICE="$(systemctl list-units --type service | grep ${MTA} | \
                   cut -d' ' -f1)"
        if [ "x${SERVICE}" != "x" ]; then
            if [ "$(systemctl is-active $SERVICE)" = "active" ]; then
                systemctl stop ${SERVICE}
            fi
        fi
    # Sys-v-init
    else
        SERVICE="$(find /etc/init.d/ -iname "*${MTA}*")"
        if [ "x${SERVICE}" != "x" ]; then
            if [ "x$(${SERVICE} status | grep running)" != "x" ]; then
                ${SERVICE} stop >/dev/null
            fi
        fi
    fi
done


# Include hidden files in globs
shopt -s nullglob dotglob

# Remove any mail
for MAIL_SPOOL in ${MAIL_SPOOL_LOCATIONS[@]}
do
    rm -rf ${MAIL_SPOOL}
done

exit 0
