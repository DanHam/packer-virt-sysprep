#!/usr/bin/env bash
#
# Remove log files from the guest system

# Original log list taken from Libguestfs's sysprep_operation_logfiles.ml
# See https://github.com/libguestfs/libguestfs/tree/master/sysprep
# Log directories _must_ include the trailing slash
LOG_DIR_LOCATIONS=(
  # Log files and directories
  "/var/log/"

  # GDM and session preferences
  "/var/cache/gdm/"
  "/var/lib/AccountService/users/"

  # Fingerprint service files
  "/var/lib/fprint/"

  # fontconfig caches
  "/var/cache/fontconfig/"

  # man pages cache
  "/var/cache/man/"
)

LOG_FILE_LOCATIONS=(
  # Logfiles configured by /etc/logrotate.d/*
  "/var/named/data/named.run"
  # Status file of logrotate
  "/var/lib/logrotate.status"

  # yum installation files
  "/root/install.log"
  "/root/install.log.syslog"
  "/root/anaconda-ks.cfg"
  "/root/anaconda-post.log"
  "/root/initial-setup-ks.cfg"


  # Pegasus certificates and other files
  "/etc/Pegasus/*.cnf"
  "/etc/Pegasus/*.crt"
  "/etc/Pegasus/*.csr"
  "/etc/Pegasus/*.pem"
  "/etc/Pegasus/*.srl"
)

# Essential services list for systemd based system - any services not
# matched by the lists below will be stopped.
# These are formatted for use with grep -P. While the P (Perl compatible
# regex) flag is experimental this seems to work ok. The lines are split
# for readability purposes only.
SYSD_LIST_1="^auditd|^dbus|^getty|^network|^sshd|^user"
# When used in the context below this will result in the systemd-journald
# service being stopped. All other systemd services will be untouched
SYSD_LIST_2="^systemd-(?!journald.*)"

# Essential services list for sys-v-init based systems - any services not
# matched by the lists below will be stopped.
SYSV_LIST="^blk-availability|^messagebus|^network|^restorecond|^sshd"
# Entries under /etc/init.d that we don't want to match
SYSV_EXCL="^killall|^halt"

# Determine if we are running on a systemd or sys-v-init based system
[[ "x$(command -v systemctl)" = "x" ]] || SYSD="true" && SYSV="true"

# Get list of services that need to be stopped
if [ "${SYSD}" = true ]; then
    # systemd services list
    SERVICES="$(systemctl list-units --state running --type service | \
                grep ^.*.service | \
                grep -Pv ${SYSD_LIST_1} | \
                grep -Pv ${SYSD_LIST_2} | \
                cut -d' ' -f1)"
else
    # sys-v services list. This is actually a list of _all_ services as
    # there doesn't seem to be a nice way to enumerate the names of
    # running services with chkconfig or service --status-all. For some
    # systems we cannot rely on the chkconfig command being present either
    # Instead we will just run the stop command against all services and
    # ignore the fact that some were not running to begin with
    SERVICES="$(find /etc/init.d/ -type f -executable | \
                xargs -I FILE basename FILE | \
                egrep -v ${SYSV_LIST} | \
                egrep -v ${SYSV_EXCL})"
fi

# Loop through and stop services
for SERVICE in ${SERVICES}
do
    [[ "${SYSD}" ]] && systemctl stop ${SERVICE} &>/dev/null
    [[ "${SYSV}" ]] && service ${SERVICE} stop &>/dev/null
done
# The auditd service needs special treatment on systemd based systems
# The service itself cannot be stopped with systemctl. However, logging
# can be stopped using the service command
[[ "${SYSD}" ]] && service auditd stop &>/dev/null



# Now all but essential services have been stopped all logging should be
# stopped and we can safely remove all log files

# Remove files from given log directories
for DIR in ${LOG_DIR_LOCATIONS[@]}
do
    [[ -d ${DIR} ]] && find ${DIR} -type f | xargs -I FILE rm -f FILE
done

# Remove given log files
for FILE in ${LOG_FILE_LOCATIONS[@]}
do
    [[ -e ${FILE} ]] && rm -f ${FILE}
done

exit 0
