#!/usr/bin/env bash
#
# Remove the local machine id prevent the possibility of machines having
# duplicate identities post cloning operations
#
# The machine id is a identifier first generated at install from a random
# source. The id then persists for all subsequent boots and can be used to
# uniquely identify the system within the network. The machine-id is often
# used in preference to other identifiers such as a mac address, that may
# infact change over the lifetime of the machine
#
# For older systems the machine-id is located at /var/lib/dbus/machine-id
# and is generated using the dbus-uuid utility.
# To trigger the generation of a new machine-id, the machine-id file must
# simply be removed. dbus will then create a new file and populate it with
# a machine-id string on next boot. Note that if the file is only emptied
# (rather than completely removed) then dbus will simply complain about
# the fact and will NOT generate a new machine-id.
#
# For more modern systems the machine-id file is located at
# /etc/machine-id and /var/lib/dbus/machine-id (if present) is either a
# copy of /etc/machine-id or is simply a symlink pointing to it.
# Modern systems now use the 'systemd-machine-id-setup' utility to
# generate the id file in place of the dbus-uuid tool employed on older
# systems.
# To trigger the generation of a new machine-id the machine-id file under
# /etc must be emptied (NOT removed) and the machine-id file under
# /var/lib/dbus (as with older systems) must be removed. If the
# /etc/machine-id file is removed rather than emptied the system will not
# be able to generate a new machine-id. This has rather dire consequences
# for the boot process.
# Additionally, if the /etc/machine-id file is emptied but the
# /var/lib/dbus/machine-id file remains populated with an id string
# then the system will simply copy the dbus machine-id string
# into /etc/machine-id on next boot - in other words a new id won't be
# created and the old id will be copied back into /etc/machine-id

# Machine ID file locations
SYSD_ID="/etc/machine-id"
DBUS_ID="/var/lib/dbus/machine-id"

# Remove and recreate (and so empty) the machine-id file under /etc
if [ -e ${SYSD_ID} ]; then
    rm -f ${SYSD_ID} && touch ${SYSD_ID}
fi

# Remove the machine-id file under /var/lib/dbus if it is not a symlink
if [[ -e ${DBUS_ID} && ! -h ${DBUS_ID} ]]; then
    rm -f ${DBUS_ID}
fi

exit 0
