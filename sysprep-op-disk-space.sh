#!/usr/bin/env bash
#
# Zero out the free space to save space
set -o errexit

# disk-space: Zero out the free space to save space
#     * /EMPTY_FILE
echo "*** Zero out the free space to save space"

dd if=/dev/zero of=/EMPTY_FILE bs=1M &> /dev/null || echo "dd exit code $? is suppressed"
rm -f /EMPTY_FILE
