#!/usr/bin/env bash
#
# Remove temporary files from the guest
#
# Basic outline:
# 1. Section 1 of 'Main' loop:
#    Create a tmpfs file system and copy any existing files from the temp
#    directory to the new file system
# 2. Section 2 of 'Main' loop:
#    Mount the tmpfs file system over the top of the existing on-disk temp
#    files directory. This *hopefully* means than any process relying on
#    files in the temp directory will still have access to them and will
#    allow a clean shutdown while still allowing removal of all on disk
#    temp files.
#    Since tmpfs file systems live on memory the contents copied to them
#    will disappear on shutdown
# 3. Section 3 of 'Main' loop:
#    Once the tmpfs file system has been mounted the original on-disk temp
#    directory will no longer be directly accessible. In order to access
#    and clear any temp files from these disk areas we need to re-mount or
#    bind mount the device or file system on which the temp directory is
#    residing to an alternate location. We can then access and remove
#    any files from the disk by doing so from the alternate mount point.

# Absolute path to guest temp file directories
TMP_LOCATIONS=(
    "/tmp"
    "/var/tmp"
)

# Set mountpoint used to access original on disk content
MNTPNT_ORIG_TMP="/mnt/orig_tmp"

# Include hidden files in glob
shopt -s dotglob

# Since the current contents of the temp file system will essentially be
# copied into memory, we need to ensure that we don't cause an out of
# memory condition for the guest. The limit of 128m should be extremely
# generous for most systems
SUM_TMP_SPACE=0
for TMP in ${TMP_LOCATIONS[@]}
do
    if [ -d ${TMP} ]; then
        TMP_SPACE="$(du -sm ${TMP} | cut -f1)"
    else
        TMP_SPACE=0
    fi
    SUM_TMP_SPACE=$(( ${SUM_TMP_SPACE} + ${TMP_SPACE} ))
    if [ ${SUM_TMP_SPACE} -gt 128 ]; then
        echo "ERROR: Space for copying tmp into memory > 128mb. Exiting"
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


# Main
for TMP in ${TMP_LOCATIONS[@]}
do
    # Test if the path or its parents are already on a tmpfs file system
    TMP_PATH="${TMP}"
    ON_TMPFS=false

    while [[ ${TMP_PATH:0:1} = "/" ]] && [[ ${#TMP_PATH} > 1 ]] && \
          [[ ${ON_TMPFS} = false ]]
    do
        DEFIFS=${IFS}
        IFS=$'\n' # Set for convenience with mount output
        for MOUNTPOINT in $(mount -l -t tmpfs | cut -d' ' -f3)
        do
            if [ "${MOUNTPOINT}" == "${TMP_PATH}" ]; then
                ON_TMPFS=true
                continue # No need to test further
            fi
        done
        IFS=${DEFIFS} # Restore the default IFS and split behaviour
        TMP_PATH=${TMP_PATH%/*} # Set to test parent on next iteration
    done

    # Perform required operations to delete temp files
    if [ "${ON_TMPFS}" = false ]; then
        # Initialise/reset the var used to store where the temp is located
        TMP_LOCATED_ON=""
        # If the temp directory is a mounted partition we need the device
        DEFIFS=${IFS} && IFS=$'\n' # Set for convenience with df output
        for LINE in $(df | tr -s ' ')
        do
            # Sixth column of df output is the mountpoint
            MNTPNT="$(echo ${LINE} | cut -d' ' -f6 | grep ^${TMP}$)"
            if [ "x${MNTPNT}" != "x" ]; then
                # First column of df output is the device
                TMP_LOCATED_ON="$(echo $LINE | cut -d' ' -f1)"
            fi
            unset MNTPNT
        done
        IFS=${DEFIFS} # Restore the default IFS and split behaviour
        # If the temp directory is not a mounted partition it must be on
        # the root file system
        [[ "x${TMP_LOCATED_ON}" = "x" ]] && TMP_LOCATED_ON="/"


        # Recreate the temp directory under /dev/shm (on tmpfs)
        SHMTMP="/dev/shm/${TMP}"
        mkdir -p ${SHMTMP}
        chmod 1777 ${SHMTMP}
        # Copy all files from original temp dir to new tmpfs based dir
        FILES=(${TMP}/*) # Array allows wildcard/glob with [[ test ]]
        [[ -e ${FILES} ]] && cp -pr ${TMP}/* ${SHMTMP}
        # Replace the original disk based temp directory structure with
        # the ephemeral tmpfs based storage by mounting it over the top of
        # the original temp directories location on the file system
        mount --bind ${SHMTMP} ${TMP}


        # Create a mount point from which the contents of the original
        # on-disk temp directory can be accessed post mount of the tmpfs
        # file system
        mkdir ${MNTPNT_ORIG_TMP}
        # Mount or bind mount in order to access the original on disk temp
        if [ ${TMP_LOCATED_ON} = "/" ]; then
            # Temp file system is a folder on the root file system
            MOUNT_OPTS="--bind"
            # Contents will be under mount point + original path e.g
            # /mountpoint/var/tmp
            TMP_PATH="${MNTPNT_ORIG_TMP}/${TMP}"
        else
            # Temp file system is a disk partition
            MOUNT_OPTS=""
            # Contents will be directly available under the mount point
            TMP_PATH="${MNTPNT_ORIG_TMP}"
        fi
        # Mount the device holding the temp file system or bind mount the
        # root file system
        mount ${MOUNT_OPTS} ${TMP_LOCATED_ON} ${MNTPNT_ORIG_TMP}
        # Delete all files from the on-disk temp directory
        FILES=(${TMP_PATH}/*)
        [[ -e ${FILES} ]] && rm -rf ${TMP_PATH}/*
        # Cleanup
        umount ${MNTPNT_ORIG_TMP} && rm -rf ${MNTPNT_ORIG_TMP}
    fi
done

exit 0
