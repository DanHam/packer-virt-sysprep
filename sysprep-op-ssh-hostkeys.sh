#!/usr/bin/env bash
#
# Remove the guests ssh host keys.
#
# The ssh server package shipped with Red Hat variants and SUSE/openSUSE
# checks for the existance of ssh keys at service start up and
# automatically generates new keys if they are missing.
#
# The ssh server package shipped with Debian and Debian derivatives (such
# as Ubuntu) do not automatically generate host ssh keys if they are
# absent from the system at service start
#
# As such, for Red Hat and Red Hat derivatives removing the hosts ssh keys
# is all that is required to ensure new keys are generated the next time
# the server is started. For Debian and its derivatives some additional
# work is required to generate new keys when the server is next booted.
# This work is comprised of the following steps:
#
#     * The service must be configured NOT to start at boot
#     * A script must placed on the system to run when the system is next
#       booted. It must:
#       - Check for and generate new host ssh keys as required
#       - Ensure the service is configured to once again start at boot
#       - Ensure the service is running post reconfiguration
#       - Remove itself from the system (run once only)

rm -f /etc/ssh/*_host_*

# If Debian's package manager configuration tool is present on the system
# we can be confident we are on a system running Debian or a Debian
# derivative
if [ "x$(command -v dpkg-reconfigure)" != "x" ]
then
    # Prevent the ssh server from starting at next boot with no host keys
    if [ "x$(command -v systemctl)" != "x" ]
    then
        # Systemd based system
        systemctl disable ssh.service >/dev/null 2>&1
    else
        # SysV based system
        update-rc.d ssh disable >/dev/null 2>&1
    fi

    # Add a script to create host ssh keys and reconfigure and start sshd
    # The /etc/rc.local script is replaced with the script we need to run
    # and restored by the script when it is run
    cp /etc/rc.local /etc/rc.local.bak
    printf "%s" \
        '#!/usr/bin/env bash
        #
        # Ensure the existance of ssh host keys for the system.
        # Configure the sshd service to start at boot and ensure it is
        # running post config

        # Generate host ssh keys if required
        if [ "x$(find /etc/ssh/ -name "*_host_*")" = "x" ]
        then
            # Reconfiguring the package triggers the post inst scripts to
            # generate the host keys
            dpkg-reconfigure openssh-server >/dev/null 2>&1
        fi

        # Config the ssh server to start at boot and ensure it is started
        if [ "x$(command -v systemctl)" != "x" ]
        then
            systemctl enable ssh.service >/dev/null 2>&1
            systemctl start ssh.service >/dev/null 2>&1
        else
            update-rc.d ssh enable >/dev/null 2>&1
            /etc/init.d/ssh start >/dev/null 2>&1
        fi

        # Restore the original /etc/rc.local script
        mv -f /etc/rc.local.bak /etc/rc.local

        exit 0
    ' | sed 's/^ *//g' > /etc/rc.local
fi

exit 0
