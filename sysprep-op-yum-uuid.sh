#!/usr/bin/env bash
#
# Remove the yum package manager UUID associated with the guest
#
# A new UUID will be automatically generated the next time yum is run

UUID="/var/lib/yum/uuid"
[[ -e ${UUID} ]] && rm -f ${UUID}

exit 0
