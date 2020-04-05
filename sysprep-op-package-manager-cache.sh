#!/usr/bin/env bash
#
# Remove cache files associated with the guests package manager
set -o errexit

# Set the locations under which various package managers store cache files
cache_locations=(
    # Debian and derivatives
    /var/cache/apt/
    /var/cache/debconf
    /var/lib/apt/lists/
    # Fedora
    /var/cache/dnf/
    # Red Hat and derivatives
    /var/cache/yum/
    # SUSE and openSUSE
    /var/cache/zypp*
)

# package-manager-cache: Remove package manager cache by removing files
# under:
#     * /var/cache/apt/archives/
#     * /var/cache/dnf/
#     * /var/cache/yum/
#     * /var/cache/zypp*
echo "*** Removing cache files associated with the system package manager"

# Note that globs in the cache locations will be auto expanded by bash
for cache_dir in "${cache_locations[@]}"
do
    if [ -d "${cache_dir}" ]; then
        # Recursively remove all files from under the given directory
        find "${cache_dir}" -type f -delete
    fi
done

exit 0
