# https://hub.docker.com/_/ubuntu/tags?page=1&name=noble
FROM debian:stable-slim

# Set arguments and enviroments
ENV TZ="Europe/Berlin"

# Stop dpkg-reconfigure tzdata from prompting for input
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postfix \
        postfix-mysql \
        dovecot-core \
        dovecot-imapd \
        dovecot-pop3d \
        dovecot-lmtpd \
        dovecot-mysql \
        dovecot-sieve \
        dovecot-managesieved \
        libsasl2-modules \
        rsyslog \
        logrotate \
        netcat-openbsd \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Add dovecot mailbox user
RUN groupadd -g 1000 vmail && \
    useradd -u 1000 -s /usr/sbin/nologin -g vmail vmail

# Add LMTP folder with permissions
RUN mkdir -p /var/spool/postfix/private && \
    chown root:root /var/spool/postfix && \
    chown postfix:postfix /var/spool/postfix/private && \
    chmod 0700 /var/spool/postfix/private
 
# Logging to files and stdout with rsyslog
RUN mkdir -p /var/log/mail && \
    touch /var/log/mail.log /var/log/mail.err /var/log/dovecot.log && \
    chmod 0644 /var/log/mail.log /var/log/mail.err /var/log/dovecot.log
RUN rm -rf /etc/rsyslog.d/*
RUN printf "module(load=\"imuxsock\")\nmail.* -/var/log/mail.log\n*.* action(type=\"omfile\" file=\"/dev/stdout\")\n" \
    > /etc/rsyslog.conf

#Logfile rotation
COPY logrotate-mail /etc/logrotate.d/mail

# Add entrypoint script
COPY dockerscripts/ /
RUN chmod +x /entrypoint.sh && sed -i 's/\r$//' /entrypoint.sh

EXPOSE 25 587 143 993 995

# HEALTHCHECK (Postfix + Dovecot + LMTP)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD nc -z localhost 25 && \
        nc -z localhost 143 && \
        test -S /var/spool/postfix/private/dovecot-lmtp && \
        nc -U -z /var/spool/postfix/private/dovecot-lmtp < /dev/null; \
    if [ $$? -ne 0 ]; then exit 1; fi

ENTRYPOINT ["/entrypoint.sh"]

