#!/usr/bin/env bash
#
# Remove DHCP client lease information
set -o errexit

lease_data_locations=(
    "/var/lib/dhclient/*"
    "/var/lib/dhcp/*"
)

# Include hidden files in glob
shopt -s nullglob dotglob

for lease_data in ${lease_data_locations[@]}
do
    rm -rf ${lease_data}
done

exit 0
