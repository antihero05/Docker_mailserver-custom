#!/bin/bash
set -e

# Ensure LMTP directory exists
mkdir -p /var/spool/postfix/private

# Start rsyslog
rsyslogd -n &
RSYSLOG_PID=$!

# Start Postfix
postfix start-fg &
POSTFIX_PID=$!

# Start Dovecot
dovecot -F &
DOVECOT_PID=$!

# Wait for any process to exit
wait -n $RSYSLOG_PID $POSTFIX_PID $DOVECOT_PID


exit $?
