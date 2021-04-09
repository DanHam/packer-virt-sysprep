#!/usr/bin/env bash
#
# Remove cache files associated with the guests package manager
set -o errexit

# Set the locations under which various package managers store cache files
cache_locations=(
    # Debian and derivatives
    "/var/cache/apt/"
    # Fedora
    "/var/cache/dnf/"
    # Red Hat and derivatives
    "/var/cache/yum/"
    # SUSE and openSUSE
    "/var/cache/zypp*"
)

# Note that globs in the cache locations will be auto expanded by bash
for cache_dir in ${cache_locations[@]}
do
    if [ -d ${cache_dir} ]; then
        # Recursively remove all files from under the given directory
        find ${cache_dir} -type f | xargs -I FILE rm -f FILE
    fi
done

exit 0
