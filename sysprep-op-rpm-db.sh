#!/usr/bin/env bash
#
# Remove any host specific RPM database files
#
# RPM will recreate these files automatically if needed

rm -f /var/lib/rpm/__db.*

exit 0
