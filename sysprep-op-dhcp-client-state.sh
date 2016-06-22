#!/usr/bin/env bash
#
# Remove DHCP client lease information

LEASE_DATA_LOCATIONS=(
    "/var/lib/dhclient/*"
    "/var/lib/dhcp/*"
)

# Include hidden files in glob
shopt -s nullglob dotglob

for LEASE_DATA in ${LEASE_DATA_LOCATIONS[@]}
do
    rm -rf ${LEASE_DATA}
done

exit 0
