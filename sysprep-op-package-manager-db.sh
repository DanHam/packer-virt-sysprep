#!/usr/bin/env bash
#
# Remove dynamically created package manager files
#
set -o errexit

# RPM Host DB files. RPM will recreate these files automatically if needed
rm -f /var/lib/rpm/__db.*

# APT lists. APT will recreate these on the first 'apt update'
apt_lists=/var/lib/apt/lists
if [ -d "${apt_lists}" ]; then
    find "${apt_lists}" -type f | xargs rm -f
fi

exit 0
