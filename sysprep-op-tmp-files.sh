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
set -o errexit

# Absolute path to guest temp file directories
tmp_locations=(
    "/tmp"
    "/var/tmp"
)

# Set mountpoint used to access original on disk content
mntpnt_orig_tmp="/mnt/orig_tmp"

# tmp-files: Remove all temporary files and directories by removing:
#     * /tmp/*
#     * /var/tmp/*
echo "*** Removing all temporary files"

# Include hidden files in glob
shopt -s dotglob

# Since the current contents of the temp file system will essentially be
# copied into memory, we need to ensure that we don't cause an out of
# memory condition for the guest. The limit of 128m should be extremely
# generous for most systems
sum_tmp_space=0
# shellcheck disable=SC2068
for tmp in ${tmp_locations[@]}
do
    if [ -d "${tmp}" ]; then
        tmp_space="$(du -sm "${tmp}" | cut -f1)"
    else
        tmp_space=0
    fi
    sum_tmp_space=$(( sum_tmp_space + tmp_space ))
    if [ ${sum_tmp_space} -gt 128 ]; then
        echo "ERROR: Space for copying tmp into memory > 128mb. Exiting"
        exit 1
    fi
done

# Test for tmpfs filesystem at /dev/shm creating one if it doesn't exist
# If /dev/shm is not present, attempt to create it
if ! mount -l -t tmpfs | grep /dev/shm &>/dev/null; then
    [[ -d /dev/shm ]] || mkdir /dev/shm && chmod 1777 /dev/shm
    mount -t tmpfs -o defaults,size=128m tmpfs /dev/shm
fi


# Main
# shellcheck disable=SC2068
for tmp in ${tmp_locations[@]}
do
    # Test if the path or its parents are already on a tmpfs file system
    tmp_path="${tmp}"
    on_tmpfs=false

    while [[ ${tmp_path:0:1} = "/" ]] && [[ ${#tmp_path} -gt 1 ]] && \
          [[ ${on_tmpfs} = false ]]
    do
        defifs=${IFS}
        IFS=$'\n' # Set for convenience with mount output
        for mountpoint in $(mount -l -t tmpfs | cut -d' ' -f3)
        do
            if [ "${mountpoint}" == "${tmp_path}" ]; then
                on_tmpfs=true
                continue # No need to test further
            fi
        done
        IFS=${defifs} # Restore the default IFS and split behaviour
        tmp_path=${tmp_path%/*} # Set to test parent on next iteration
    done

    # Perform required operations to delete temp files
    if [ "${on_tmpfs}" = false ]; then
        # Initialise/reset the var used to store where the temp is located
        tmp_located_on=""
        # If the temp directory is a mounted partition we need the device
        defifs=${IFS} && IFS=$'\n' # Set for convenience with df output
        for line in $(df | tr -s ' ')
        do
            # Sixth column of df output is the mountpoint
            if echo "${line}" | cut -d' ' -f6 | grep "^${tmp}$" &>/dev/null; then
                # First column of df output is the device
                tmp_located_on="$(echo "${line}" | cut -d' ' -f1)"
            fi
        done
        IFS=${defifs} # Restore the default IFS and split behaviour
        # If the temp directory is not a mounted partition it must be on
        # the root file system
        [[ "x${tmp_located_on}" = "x" ]] && tmp_located_on="/"


        # Recreate the temp directory under /dev/shm (on tmpfs)
        shmtmp="/dev/shm/${tmp}"
        mkdir -p "${shmtmp}"
        chmod 1777 "${shmtmp}"
        # Copy all files from original temp dir to new tmpfs based dir
        if [[ -n "$(ls -A "${tmp}")" ]]; then
          cp -pr "${tmp}"/* "${shmtmp}"
        fi
        # Replace the original disk based temp directory structure with
        # the ephemeral tmpfs based storage by mounting it over the top of
        # the original temp directories location on the file system
        mount --bind "${shmtmp}" "${tmp}"


        # Create a mount point from which the contents of the original
        # on-disk temp directory can be accessed post mount of the tmpfs
        # file system
        mkdir ${mntpnt_orig_tmp}
        # Mount or bind mount in order to access the original on disk temp
        if [ ${tmp_located_on} = "/" ]; then
            # Temp file system is a folder on the root file system
            mount_opts="--bind"
            # Contents will be under mount point + original path e.g
            # /mountpoint/var/tmp
            tmp_path="${mntpnt_orig_tmp}/${tmp}"
        else
            # Temp file system is a disk partition
            mount_opts=""
            # Contents will be directly available under the mount point
            tmp_path="${mntpnt_orig_tmp}"
        fi
        # Mount the device holding the temp file system or bind mount the
        # root file system
        mount "${mount_opts}" ${tmp_located_on} ${mntpnt_orig_tmp}
        # Delete all files from the on-disk temp directory
        rm -rf "${tmp_path:?}"/*
        # Cleanup
        umount ${mntpnt_orig_tmp} && rm -rf ${mntpnt_orig_tmp}
    fi
done

exit 0
