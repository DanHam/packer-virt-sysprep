#!/usr/bin/env bash
#
# Remove network configuration
#
# CentOS 7 is setting the MAC address as HWADDR parameter in the network
# configuration files (/etc/sysconfig/network-scripts/ifcfg-e*)
# [ifcfg-enp0s31f6, ifcfg-eth0]
# These files can be removed, because default config are regenarted if necessary.

set -o errexit

network_config_locations=(
    "/etc/sysconfig/network-scripts/ifcfg-e*"
)

netplan_networkd_config="/etc/netplan/01-netcfg.yaml"
netplan_networkmanager_config="/etc/netplan/01-network-manager-all.yaml"

# network: Remove network-scripts/ifcfg-e* config files
#     * /etc/sysconfig/network-scripts/ifcfg-e*
echo "*** Remove network-scripts/ifcfg-e* config files"

# Include hidden files in glob
shopt -s nullglob

# shellcheck disable=SC2068
for network_config in ${network_config_locations[@]}; do
    rm "${network_config}"
done

# This needs to be executed on the Ubuntu server installation (mini.iso) when installing Desktop environment using
# `tasksel tasksel/first multiselect ubuntu-desktop`

# By default Ubuntu server installation (mini.iso) creates the `/etc/netplan/01-netcfg.yaml` and installing ubuntu-desktop using tasksel
# adds `/etc/netplan/01-network-manager-all.yaml`. Having both these files for Ubuntu Desktop brings problems.
# Some details can be found here: https://github.com/hashicorp/vagrant/issues/11378
# In short the `/etc/netplan/01-netcfg.yaml` should not be present on the Ubuntu Desktop installation.
# `/etc/netplan/01-network-manager-all.yaml` should be used for NetworkManager configuration (only)

echo "*** Remove /etc/netplan/01-netcfg.yaml in Ubuntu Desktop"

if [[ -s "${netplan_networkd_config}" ]] && [[ -s "${netplan_networkmanager_config}" ]]; then
  rm "${netplan_networkd_config}"
fi

exit 0
