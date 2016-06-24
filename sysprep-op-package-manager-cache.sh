#!/usr/bin/env bash
#
# Remove cache files associated with the guests package manager

# Set the locations under which various package managers store cache files
CACHE_LOCATIONS=(
    # Debian and derivatives
    "/var/cache/apt/archives/"
    # Fedora
    "/var/cache/dnf/"
    # Red Hat and derivatives
    "/var/cache/yum/"
    # SUSE and openSUSE
    "/var/cache/zypp*"
)

# Note that globs in the cache locations will be auto expanded by bash
for CACHE_DIR in ${CACHE_LOCATIONS[@]}
do
    if [ -d ${CACHE_DIR} ]; then
        # Recursively remove all files from under the given directory
        find ${CACHE_DIR} -type f | xargs -I FILE rm -f FILE
    fi
done

exit 0
