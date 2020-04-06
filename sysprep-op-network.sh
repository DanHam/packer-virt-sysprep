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
netplan_config="/etc/netplan/01-netcfg.yaml"

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

# By default Ubuntu server installation (mini.iso) creates the `/etc/netplan/01-netcfg.yaml` and `/etc/netplan/01-network-manager-all.yaml` which causes problems to Vagrant.
# Some details can be found here: https://github.com/hashicorp/vagrant/issues/11378
# In short the /etc/netplan/01-netcfg.yaml should not be on the Ubuntu Desktop installation when using Vagrant otherwise `vagrant up` is hanging.

if [[ -s "${netplan_config}" ]] ; then
  rm "${netplan_config}"
fi

exit 0
