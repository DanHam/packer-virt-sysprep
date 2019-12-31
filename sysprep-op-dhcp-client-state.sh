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

# Ensure all interfaces are down prior to removing the leases file.
# Otherwise the file is recreated by ifdown/dhclient
for iface in $(ls /sys/class/net/ | grep -v lo); do
    # Wait for each interface to be taken down. Timeout after 20 secs
    timer=0
    while grep up "/sys/class/net/${iface}/operstate" &>/dev/null && \
        [[ timer -lt 20 ]]; do
        sleep 1
        let timer=${timer}+1
    done

    # If the interface is still up it is likely something has gone wrong
    # with the usual procedures that take the interface down at shutdown.
    # Make a best effort attempt to take the interface down manually
    # temporarily ignoring errors
    if grep up "/sys/class/net/${iface}/operstate" &>/dev/null; then
        set +o errexit
        ifdown ${iface}
        set -o errexit
    fi

    # Some implementations start the dhcp client when the interface is taken
    # down (even if the interface is statically configured). It is the dhcp
    # client that writes out to the leases file when the interface goes
    # down. Kill the client as a precautionary measure to prevent further
    # interference. Ignore errors in case the dhclient exits between
    # obtaining its pid and killing it
    pid="$(ps aux | grep /sbin/dhclient | grep "${iface}" | tr -s " " | \
        cut -d' ' -f2)"
    if [ "x${pid}" != "x" ]; then
        set +o errexit
        kill -9 "${pid}"
        set -o errexit
    fi
done

# Now that all interfaces are down remove all lease files
for lease_file in ${lease_data_locations[@]}; do
    rm -f ${lease_file}
done

exit 0
