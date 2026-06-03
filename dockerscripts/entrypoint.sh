#!/bin/bash
set -euo pipefail

mkdir -p /run
mkdir -p /var/spool/postfix/private

chown postfix:postfix /var/spool/postfix/private
chmod 0700 /var/spool/postfix/private

# Start rsyslog
rsyslogd -n &
RSYSLOG_PID=$!

# Start postfix
postfix start-fg &
POSTFIX_PID=$!

# Start dovecot
dovecot -F &
DOVECOT_PID=$!

# Run logrotate every hour
(
    while true; do
        logrotate -s /var/lib/logrotate/status /etc/logrotate.conf || true
        sleep 3600
    done
) &
LOGROTATE_PID=$!

cleanup() {
    kill -TERM "$RSYSLOG_PID" "$POSTFIX_PID" "$DOVECOT_PID" "$LOGROTATE_PID" 2>/dev/null || true
    wait || true
}

trap cleanup TERM INT

while true; do
    kill -0 "$RSYSLOG_PID" 2>/dev/null || exit 1
    kill -0 "$POSTFIX_PID" 2>/dev/null || exit 1
    kill -0 "$DOVECOT_PID" 2>/dev/null || exit 1
    sleep 10
done
