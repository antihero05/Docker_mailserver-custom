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
        libsasl2-modules \
        rsyslog \
        netcat-openbsd \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Add dovecot mailbox user
RUN groupadd -g 1000 vmail && \
    useradd -u 1000 -s /usr/sbin/nologin -g vmail vmail

# Logging symlinks
RUN mkdir -p /var/log/mail && \
    touch /var/log/mail.log /var/log/dovecot.log && \
    ln -sf /dev/stdout /var/log/mail.log && \
    ln -sf /dev/stdout /var/log/dovecot.log && \
    ln -sf /dev/stderr /var/log/mail.err

# rsyslog -> stdout config
RUN printf "module(load=\"imuxsock\")\n#module(load=\"imklog\")\n*.* action(type=\"omfile\" file=\"/dev/stdout\")\n" \
    > /etc/rsyslog.conf

# Add entrypoint script
COPY dockerscripts/ /
RUN chmod +x /entrypoint.sh && sed -i 's/\r$//' /entrypoint.sh

EXPOSE 25 587 143 993 995

# HEALTHCHECK (Postfix + Dovecot + LMTP)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD nc -z localhost 25 && \
        nc -z localhost 143 && \
        test -S /var/spool/postfix/private/dovecot-lmtp && \
        nc -U /var/spool/postfix/private/dovecot-lmtp < /dev/null; \
    if [ $$? -ne 0 ]; then exit 1; fi


ENTRYPOINT ["/entrypoint.sh"]
