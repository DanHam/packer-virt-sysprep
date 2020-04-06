#!/usr/bin/env bash
#
# Remove any custom firewall rules or firewalld configuration
#
# Modern systems typically make use of the dynamic firewall daemon
# firewalld which provides many advantages and additional features over
# more traditional approaches. Customisation of the systems firewall rules
# it handled through user space tools that output configuration
# customisations to /etc/firewalld/zones and /etc/firewalld/services.
# Deleting these files will remove any custom configuration from the
# system
#
# Older systems or other firewall implementations usually persist rules
# information for iptables in /etc/sysconfig/iptables and use the file to
# configure the firewall at startup. As such simply deleting the file will
# be enough to remove any custom configuration from the system
set -o errexit

fw_config_locations=(
    "/etc/sysconfig/iptables"
    "/etc/firewalld/services/*"
    "/etc/firewalld/zones/*"
)

# firewall-rules: Remove custom firewall rules by removing:
#     * /etc/sysconfig/iptables
#     * /etc/firewalld/services/*
#     * /etc/firewalld/zones/*
echo "*** Removing any custom firewall rules or firewalld configuration"

# If using firewalld stop the daemon/service prior to removing the config
if command -v systemctl &>/dev/null; then
    if systemctl is-active firewalld.service &>/dev/null; then
        systemctl stop firewalld.service
    fi
fi

# Include hidden files in globs
shopt -s nullglob dotglob

# Remove any custom configuration
# shellcheck disable=SC2068
for fw_config in ${fw_config_locations[@]}
do
    rm -rf "${fw_config}"
done

exit 0
