#!/usr/bin/env bash
#
# Remove log files from the guest
#
# Basic outline for treatment of log directories:
# 1. Section 1 of 'log directories' loop:
#    Create a tmpfs file system and copy any existing files from the log
#    directory to the new file system
# 2. Section 2 of 'log directories' loop:
#    Mount the tmpfs file system over the top of the existing on-disk log
#    files directory. This *hopefully* means than any process relying on
#    files in the log directory will still have access to them and will
#    allow a clean shutdown while still allowing removal of all on disk
#    log files.
#    Since tmpfs file systems live on memory the contents copied to them
#    will disappear on shutdown
# 3. Section 3 of 'log directories' loop:
#    Once the tmpfs file system has been mounted the original on-disk log
#    directory will no longer be directly accessible. In order to access
#    and clear any log files from these disk areas we need to re-mount or
#    bind mount the device or file system on which the log directory is
#    residing to an alternate location. We can then access and remove
#    any files from the disk by doing so from the alternate mount point.
#
# Static log files are removed directly at the end of the script
#
# Original log list taken from Libguestfs's sysprep_operation_logfiles.ml
# See https://github.com/libguestfs/libguestfs/tree/master/sysprep
set -o errexit

# Absolute path to guest log file directories
# All files under the given directories will be removed
logd_locations=(
  # Log files and directories
  "/var/log"

  # GDM and session preferences
  "/var/cache/gdm"
  "/var/lib/AccountService/users"

  # Fingerprint service files
  "/var/lib/fprint"

  # fontconfig caches
  "/var/cache/fontconfig"

  # man pages cache
  "/var/cache/man"

  # ldconfig cache
  "/var/cache/ldconfig"
)

# Absolute path to static log files that can be removed directly
logf_locations=(
  # Logfiles configured by /etc/logrotate.d/*
  "/var/named/data/named.run"
  # Status file of logrotate
  "/var/lib/logrotate.status"

  # Installation files
  "/root/install.log"
  "/root/install.log.syslog"
  "/root/anaconda-ks.cfg"
  "/root/original-ks.cfg"
  "/root/anaconda-post.log"
  "/root/initial-setup-ks.cfg"

  # Pegasus certificates and other files
  "/etc/Pegasus/*.cnf"
  "/etc/Pegasus/*.crt"
  "/etc/Pegasus/*.csr"
  "/etc/Pegasus/*.pem"
  "/etc/Pegasus/*.srl"
)


# Set mountpoint used to access original on disk content
mntpnt_orig_logd="/mnt/orig_log_dir"

# logfiles: Remove logfiles at:
#     * ...a ton of different locations!
echo "*** Removing log files from various locations"

# Include hidden files in glob
shopt -s dotglob

# Since the current contents of the log directories will essentially be
# copied into memory, we need to ensure that we don't cause an out of
# memory condition for the guest. The limit of 128m should be extremely
# generous for most systems
sum_logd_space=0
# shellcheck disable=SC2068
for logd in ${logd_locations[@]}
do
    if [ -d "${logd}" ]; then
        logd_space="$(du -sm "${logd}" | cut -f1)"
    else
        logd_space=0
    fi
    sum_logd_space=$(( sum_logd_space + logd_space ))
    if [ ${sum_logd_space} -gt 128 ]; then
        echo "ERROR: Space for copying logs into memory > 128mb. Exiting"
        exit 1
    fi
done

# Test for tmpfs filesystem at /dev/shm creating one if it doesn't exist
# If /dev/shm is not present, attempt to create it
if ! mount -l -t tmpfs | grep /dev/shm &>/dev/null; then
    [[ -d /dev/shm ]] || mkdir /dev/shm && chmod 1777 /dev/shm
    mount -t tmpfs -o defaults,size=128m tmpfs /dev/shm
fi

# Remove logs from given log directories
# shellcheck disable=SC2068
for logd in ${logd_locations[@]}
do
    if [ -d "${logd}" ]; then
        # Test if the path or its parents are already on tmpfs
        logd_path="${logd}"
        on_tmpfs=false

        while [[ ${logd_path:0:1} = "/" ]] && [[ ${#logd_path} -gt 1 ]] && \
              [[ ${on_tmpfs} = false ]]
        do
            defifs=${IFS}
            IFS=$'\n' # Set for convenience with mount output
            for mountpoint in $(mount -l -t tmpfs | cut -d' ' -f3)
            do
                if [ "${mountpoint}" == "${logd_path}" ]; then
                    on_tmpfs=true
                    continue # No need to test further
                fi
            done
            IFS=${defifs} # Restore the default IFS and split behaviour
            logd_path=${logd_path%/*} # Test parent on next iteration
        done

        if [ "${on_tmpfs}" = false ]; then
            # Initialise/reset var used to store where log dir is located
            logd_located_on=""
            # If log directory is a mounted partition we need the device
            defifs=${IFS} && IFS=$'\n' # Set for convenience with df output
            for line in $(df | tr -s ' ')
            do
                # Sixth column of df output is the mountpoint
                if echo "${line}" | cut -d' ' -f6 | grep "^${logd}$" &>/dev/null; then
                    # First column of df output is the device
                    logd_located_on="$(echo "${line}" | cut -d' ' -f1)"
                fi
            done
            IFS=${defifs} # Restore the default IFS and split behaviour
            # If the log directory is not a mounted partition it must be on
            # the root file system
            [[ "x${logd_located_on}" = "x" ]] && logd_located_on="/"


            # Recreate the log directory under /dev/shm (on tmpfs)
            shmlogd="/dev/shm/${logd}"
            mkdir -p "${shmlogd}"
            chmod 1777 "${shmlogd}"
            # Copy all files from original log dir to new tmpfs based dir
            if [[ -n "$(ls -A "${logd}")" ]]; then
              cp -pr "${logd}"/* "${shmlogd}"
            fi
            # Replace the original disk based log directory structure with
            # the ephemeral tmpfs based storage by mounting it over the top of
            # the original log directories location on the file system
            mount --bind "${shmlogd}" "${logd}"


            # Create a mount point from which the contents of the original
            # on-disk log directory can be accessed post mount of the tmpfs
            # file system
            mkdir ${mntpnt_orig_logd}
            # Mount or bind mount in order to access the original on disk logs
            if [ ${logd_located_on} = "/" ]; then
                # Temp file system is a folder on the root file system
                mount_opts="--bind"
                # Contents will be under mount point + original path e.g
                # /mountpoint/var/tmp
                logd_path="${mntpnt_orig_logd}/${logd}"
            else
                # Temp file system is a disk partition
                mount_opts=""
                # Contents will be directly available under the mount point
                logd_path="${mntpnt_orig_logd}"
            fi
            # Mount the device holding the temp file system or bind mount the
            # root file system
            mount "${mount_opts}" ${logd_located_on} ${mntpnt_orig_logd}
            # The lastlog file cannot be created on demand for some reason
            # and errors occur if /var/log/lastlog is missing. So, check if
            # '/var/log/lastlog' exists and store the location so we can
            # recreate later
            if [ "${logd}" == "/var/log" ]; then
                lastlog="$(find ${logd_path} -type f -name lastlog)"
            fi
            # Delete all files from the on-disk log directory
            find "${logd_path}" -type f -delete
            # Recreate the /var/log/lastlog file if required
            if [[ "${logd}" == "/var/log" ]] && [[ "x${lastlog}" != "x" ]]; then
                touch "${lastlog}"
            fi
            # Cleanup
            umount ${mntpnt_orig_logd} && rm -rf ${mntpnt_orig_logd}
        fi
    fi
done

# Remove static log files and files that may be removed directly
# shellcheck disable=SC2068
for file in ${logf_locations[@]}
do
    [[ -e ${file} ]] && rm -f "${file}"
done


exit 0
