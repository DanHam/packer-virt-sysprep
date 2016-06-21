#!/usr/bin/env bash
#
# Remove bash history for root and system users

ROOTS_HIST="$(find /root -type f -name .bash_history)"
USERS_HIST="$(find /home -type f -name .bash_history | tr -s '\n' ' ')"

rm -f ${ROOTS_HIST} ${USERS_HIST}

exit 0
