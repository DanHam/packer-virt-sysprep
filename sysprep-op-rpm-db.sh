#!/usr/bin/env bash
#
# Remove any host specific RPM database files
#
# RPM will recreate these files automatically if needed
set -o errexit

# rpm-db: Remove host-specific RPM database files by removing:
#     # /var/lib/rpm/__db.*
echo "*** Removing RPM database files. RPM will recreate these as required"

rm -f /var/lib/rpm/__db.*

exit 0
