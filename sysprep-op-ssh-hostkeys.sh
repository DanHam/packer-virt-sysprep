#!/usr/bin/env bash
#
# Remove the guests ssh host keys.
#
# The ssh server package shipped with Red Hat variants and SUSE/openSUSE
# checks for the existance of ssh keys at service start up and
# automatically generates new keys if they are missing.
#
# The ssh server package shipped with Debian and Debian derivatives (such
# as Ubuntu [14.04]) do not automatically generate host ssh keys if they are
# absent from the system at service start
#
# As such, for Red Hat and Red Hat derivatives removing the hosts ssh keys
# is all that is required to ensure new keys are generated the next time
# the server is started. For Debian and its derivatives a service must be
# placed on the system to run when the system is next booted.
#
# Do not remove /etc/ssh/*_host_* if you are using old Debian / Ubuntu 14.04
#
set -o errexit

# ssh-hostkeys: Remove the SSH host keys in the guest by removing:
#     * /etc/ssh/*_host_*
echo "*** Removing host ssh keys. New keys will be generated at next boot"

# Remove all ssh host key types
rm -f /etc/ssh/*_host_*

exit 0
