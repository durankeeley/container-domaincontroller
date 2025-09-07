FROM ubuntu:24.04

# Set DEBIAN_FRONTEND to noninteractive to suppress prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    acl \
    attr \
    samba \
    smbclient \
    krb5-config \
    krb5-user \
    libpam-krb5 \
    winbind \
    libnss-winbind \
    libpam-winbind \
    python3-setproctitle \
    ldb-tools \
    tini \
    supervisor \
    inetutils-ping \
    dnsutils \
    iproute2 \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Remove the default smb.conf to prevent conflicts
RUN rm /etc/samba/smb.conf

# Copy the combined entrypoint script into the image
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Set Tini as the entrypoint to handle signals properly
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Add Health Check instruction
HEALTHCHECK --interval=120s --timeout=20s --retries=5 CMD ["/usr/local/bin/entrypoint.sh", "healthcheck"]
