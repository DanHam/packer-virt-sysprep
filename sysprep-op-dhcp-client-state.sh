#!/usr/bin/env bash
#
# Remove DHCP client lease information. Note that Debian 10, and possibly
# other OSes, now write a machine specific DUID (DHCP Unique ID) to the
# leases file
set -o errexit

lease_data_locations=(
    "/var/lib/dhclient/*"
    "/var/lib/dhcp/*"
)

# Include hidden files in glob
shopt -s nullglob dotglob

for lease_file in ${lease_data_locations[@]}
do
    # On shutdown ifdown/dhclient may write to (or recreate) the dhcp
    # leases file when the interface is brought down. To ensure the leases
    # file is removed we need to wait for the interface to be brought down.
    # Timeout after 20secs.
    iface="$(cat ${lease_file} | sed -nre 's/.*interface "(.*)";/\1/p' | uniq)"
    timer=0
    while grep up "/sys/class/net/${iface}/operstate" &>/dev/null && \
        [[ timer -lt 20 ]]; do
        sleep 1
        let timer=${timer}+1
    done
    # If the interface was brought down successfully, wait a few secs
    # for ifdown/dhclient to complete
    sleep 2
    # If we timed out we need to kill the dhcp client to prevent it
    # recreating the dhcp leases file. Killing the client won't hurt if the
    # interface was brought down sucessfully as the system is going down
    # anyway
    pid="$(ps aux | grep /sbin/dhclient | grep "${iface}" | tr -s " " | \
        cut -d' ' -f2)"
    if [ "x${pid}" != "x" ]; then
        kill -9 "${pid}"
    fi
    # Finally remove the leases file
    rm -f ${lease_file}
done

exit 0
