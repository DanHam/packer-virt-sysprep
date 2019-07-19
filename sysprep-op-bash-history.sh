#!/usr/bin/env bash
#
# Remove bash history for root and system users
set -o errexit

roots_hist="$(find /root -type f -name .bash_history)"
users_hist="$(find /home -type f -name .bash_history | tr -s '\n' ' ')"

rm -f ${roots_hist} ${users_hist}

exit 0
