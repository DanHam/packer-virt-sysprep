#!/usr/bin/env bash
#
# Remove DHCP client lease information. Note that Debian 10, and possibly
# other OSes, now write a machine specific DUID (DHCP Unique ID) to the
# leases file
set -o errexit

lease_data_locations=(
    "/var/lib/dhclient/*"
    "/var/lib/dhcp/*"
    "/var/lib/NetworkManager/*"
)

# dhcp-client-state: Remove DHCP client release by removing:
#     * /var/lib/dhclient/*
#     * /var/lib/dhcp/*
#     * /var/lib/NetworkManager/*
echo "*** Removing any DHCP client lease information"

# Include hidden files in glob
shopt -s nullglob dotglob

# Remove all lease files
# shellcheck disable=SC2068
for lease_file in ${lease_data_locations[@]}; do
    rm -f "${lease_file}"
done

exit 0
