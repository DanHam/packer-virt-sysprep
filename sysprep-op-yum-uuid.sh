#!/usr/bin/env bash
#
# Remove the yum package manager UUID associated with the guest
#
# A new UUID will be automatically generated the next time yum is run
set -o errexit

# yum-uuid: Remove the yum UUID
#     * /var/lib/yum/uuid
echo "*** Removing host specific Yum UUID"

uuid="/var/lib/yum/uuid"
[[ -e ${uuid} ]] && rm -f ${uuid}

exit 0
