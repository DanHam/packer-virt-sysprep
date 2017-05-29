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

# Original log list taken from Libguestfs's sysprep_operation_logfiles.ml
# See https://github.com/libguestfs/libguestfs/tree/master/sysprep

# Absolute path to guest log file directories
# All files under the given directories will be removed
LOGD_LOCATIONS=(
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
)

# Absolute path to static log files that can be removed directly
LOGF_LOCATIONS=(
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
MNTPNT_ORIG_LOGD="/mnt/orig_log_dir"

# Include hidden files in glob
shopt -s dotglob

# Since the current contents of the log directories will essentially be
# copied into memory, we need to ensure that we don't cause an out of
# memory condition for the guest. The limit of 128m should be extremely
# generous for most systems
SUM_LOGD_SPACE=0
for LOGD in ${LOGD_LOCATIONS[@]}
do
    if [ -d ${LOGD} ]; then
        LOGD_SPACE="$(du -sm ${LOGD} | cut -f1)"
    else
        LOGD_SPACE=0
    fi
    SUM_LOGD_SPACE=$(( ${SUM_LOGD_SPACE} + ${LOGD_SPACE} ))
    if [ ${SUM_LOGD_SPACE} -gt 128 ]; then
        echo "ERROR: Space for copying logs into memory > 128mb. Exiting"
        exit 1
    fi
done

# Test for tmpfs filesystem at /dev/shm creating one if it doesn't exist
# If /dev/shm is not present, attempt to create it. Exit on failure
if [ "x$(mount -l -t tmpfs | grep /dev/shm)" = "x" ]; then
    [[ -d /dev/shm ]] || mkdir /dev/shm && chmod 1777 /dev/shm
    mount -t tmpfs -o defaults,size=128m tmpfs /dev/shm
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not create tmpfs file system. Exiting"
        exit 1
    fi
fi


# Remove logs from given log directories
for LOGD in ${LOGD_LOCATIONS[@]}
do
    if [ -d ${LOGD} ]; then
        # Test if the path or its parents are already on tmpfs
        LOGD_PATH="${LOGD}"
        ON_TMPFS=false

        while [[ ${LOGD_PATH:0:1} = "/" ]] && [[ ${#LOGD_PATH} > 1 ]] && \
              [[ ${ON_TMPFS} = false ]]
        do
            DEFIFS=${IFS}
            IFS=$'\n' # Set for convenience with mount output
            for MOUNTPOINT in $(mount -l -t tmpfs | cut -d' ' -f3)
            do
                if [ "${MOUNTPOINT}" == "${LOGD_PATH}" ]; then
                    ON_TMPFS=true
                    continue # No need to test further
                fi
            done
            IFS=${DEFIFS} # Restore the default IFS and split behaviour
            LOGD_PATH=${LOGD_PATH%/*} # Test parent on next iteration
        done

        if [ "${ON_TMPFS}" = false ]; then
            # Initialise/reset var used to store where log dir is located
            LOGD_LOCATED_ON=""
            # If log directory is a mounted partition we need the device
            DEFIFS=${IFS} && IFS=$'\n' # Set for convenience with df output
            for LINE in $(df | tr -s ' ')
            do
                # Sixth column of df output is the mountpoint
                MNTPNT="$(echo ${LINE} | cut -d' ' -f6 | grep ^${LOGD}$)"
                if [ "x${MNTPNT}" != "x" ]; then
                    # First column of df output is the device
                    LOGD_LOCATED_ON="$(echo $LINE | cut -d' ' -f1)"
                fi
                unset MNTPNT
            done
            IFS=${DEFIFS} # Restore the default IFS and split behaviour
            # If the log directory is not a mounted partition it must be on
            # the root file system
            [[ "x${LOGD_LOCATED_ON}" = "x" ]] && LOGD_LOCATED_ON="/"


            # Recreate the log directory under /dev/shm (on tmpfs)
            SHMLOGD="/dev/shm/${LOGD}"
            mkdir -p ${SHMLOGD}
            chmod 1777 ${SHMLOGD}
            # Copy all files from original log dir to new tmpfs based dir
            FILES=(${LOGD}/*) # Array allows wildcard/glob with [[ test ]]
            [[ -e ${FILES} ]] && cp -pr ${LOGD}/* ${SHMLOGD}
            # Replace the original disk based log directory structure with
            # the ephemeral tmpfs based storage by mounting it over the top of
            # the original log directories location on the file system
            mount --bind ${SHMLOGD} ${LOGD}


            # Create a mount point from which the contents of the original
            # on-disk log directory can be accessed post mount of the tmpfs
            # file system
            mkdir ${MNTPNT_ORIG_LOGD}
            # Mount or bind mount in order to access the original on disk logs
            if [ ${LOGD_LOCATED_ON} = "/" ]; then
                # Temp file system is a folder on the root file system
                MOUNT_OPTS="--bind"
                # Contents will be under mount point + original path e.g
                # /mountpoint/var/tmp
                LOGD_PATH="${MNTPNT_ORIG_LOGD}/${LOGD}"
            else
                # Temp file system is a disk partition
                MOUNT_OPTS=""
                # Contents will be directly available under the mount point
                LOGD_PATH="${MNTPNT_ORIG_LOGD}"
            fi
            # Mount the device holding the temp file system or bind mount the
            # root file system
            mount ${MOUNT_OPTS} ${LOGD_LOCATED_ON} ${MNTPNT_ORIG_LOGD}
            # Delete all files from the on-disk log directory
            find ${LOGD_PATH}/ -type f | xargs -I FILE rm -f FILE
            # Cleanup
            umount ${MNTPNT_ORIG_LOGD} && rm -rf ${MNTPNT_ORIG_LOGD}
        fi
    fi
done

# Remove static log files and files that may be removed directly
for FILE in ${LOGF_LOCATIONS[@]}
do
    [[ -e ${FILE} ]] && rm -f ${FILE}
done


exit 0
