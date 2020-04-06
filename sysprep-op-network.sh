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
    /etc/sysconfig/network-scripts/ifcfg-e*
)

# network: Remove MAC (HWADDR) or UUID form network-scripts/ifcfg-e* config files
#     * /etc/sysconfig/network-scripts/ifcfg-e*
echo "*** Remove MAC (HWADDR) or UUID form network-scripts/ifcfg-e* config files"

# Include hidden files in glob
shopt -s nullglob dotglob

for network_config in "${network_config_locations[@]}"; do
    sed -i -e "/^HWADDR=/d" -e "/^UUID=/d" "${network_config}"
done

# This needs to be executed on the Ubuntu server installation (mini.iso) when installing Desktop environment using
# `tasksel tasksel/first multiselect ubuntu-desktop`

# By default Ubuntu server installation (mini.iso) creates the `/etc/netplan/01-netcfg.yaml` and `/etc/netplan/01-network-manager-all.yaml` which causes problems to Vagrant.
# Some details can be found here: https://github.com/hashicorp/vagrant/issues/11378
# In short the /etc/netplan/01-netcfg.yaml should not be on the Ubuntu Desktop installation when using Vagrant otherwise `vagrant up` is hanging.

if [[ -s /etc/netplan/01-netcfg.yaml ]] ; then
  rm /etc/netplan/01-netcfg.yaml
fi

exit 0
