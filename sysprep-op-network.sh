#!/usr/bin/env bash
#
# Remove any HWADDR or UUID parameters from network configuration
#
# CentOS 7 is setting the MAC address as HWADDR parameter in the network
# configuration files (/etc/sysconfig/network-scripts/ifcfg-e*)
# [ifcfg-enp0s31f6, ifcfg-eth0]
# It may also add UUID which should be also removed.

set -o errexit

network_config_locations=(
    "/etc/sysconfig/network-scripts/ifcfg-e*"
)

# Include hidden files in glob
shopt -s nullglob dotglob

for network_config in "${network_config_locations[@]}"; do
    sed -i '/^(HWADDR|UUID)=/d' "${network_config}"
done

exit 0
