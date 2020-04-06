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
# the server is started. For Debian and its derivatives a service must be
# placed on the system to run when the system is next booted. It must:
#
#    - Run prior to start up of the sshd server
#    - Check for and generate new host ssh keys as required
#    - Remove itself from the system after completion (run once only)
#
set -o errexit

unit_file="/etc/systemd/system/generate-ssh-host-keys.service"
keygen_file="/generate-ssh-host-keys.sh"
cleanup_file="/generate-ssh-host-keys-cleanup.sh"

# Remove all ssh host key types
rm -f /etc/ssh/*_host_*

# If Debian's package manager configuration tool is present on the system
# we can be confident we are on a system running Debian or a Debian
# derivative
if command -v dpkg-reconfigure &>/dev/null; then
    # Create a service that will run before the sshd service/network is up
    cat << EOF | sed -r 's/^ {1,}//g' > "${unit_file}"
        [Unit]
        Description=Generate ssh host keys as required
        Before=network-pre.target
        Requires=network-pre.target

        [Service]
        Type=oneshot
        ExecStart=/bin/bash "${keygen_file}"
        ExecStart=/bin/bash "${cleanup_file}"
        ExecStop=/bin/true

        [Install]
        WantedBy=multi-user.target
EOF

    # Create the script called by the service to generate ssh host keys
    cat << \EOF | sed -r 's/^ {8}//g' > "${keygen_file}"
        #!/usr/bin/env bash
        #
        # Generate ssh host keys for the system if required.
        set -o errexit
        types="rsa ecdsa ed25519" # Recommended types
        for type in ${types}
        do
            keyfile="/etc/ssh/ssh_host_${type}_key"
            # Generate the key if the file is missing or empty
            if [ ! -s "${keyfile}" ]; then
                echo "Generating SSH ${type^^} key"
                /usr/bin/ssh-keygen -t "${type}" -q -N "" -f "${keyfile}"
            fi
        done

        exit 0
EOF

    # Create the script that will clean up and remove everything after the
    # first run
    cat << EOF | sed -r 's/^ {8}//g' > "${cleanup_file}"
        #!/usr/bin/env bash
        #
        # Clean up
        set -o errexit

        # Remove the generate-ssh-host-keys.service unit file
        rm -f "${unit_file}"

        # Remove the key generation script
        rm -f "${keygen_file}"

        # Remove link from multi-user.target.wants
        rm -f "/etc/systemd/system/multi-user.target.wants/$(basename ${unit_file})"

        # Reload systemd to pick up the changes
        systemctl daemon-reload

        # Remove this script
        rm -f "${cleanup_file}"

        exit 0
EOF

    # Manually enable the unit. Note that using systemctl commands here can
    # cause issues if the packer-virt-sysprep scripts are themselves being
    # executed by a systemd unit. For example, systemd will stop running
    # the executing unit if a systemctl daemon-reload is issued in any of
    # the scripts that it calls. This means additional ExecStop commands
    # issued in the calling unit will not be executed.
    ln -s ${unit_file} /etc/systemd/system/multi-user.target.wants
fi

exit 0
