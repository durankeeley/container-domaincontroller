#!/bin/bash
set -e

CONFIG_FILE="/etc/samba/config/smb.conf"

# Sets a parameter in smb.conf, overwriting any existing value.
set_samba_param() {
    local section=$1 param=$2 value=$3
    sed -i "/^\s*${param}\s*=/d" "$CONFIG_FILE"
    sed -i "/\[${section}\]/a \\\t${param} = ${value}" "$CONFIG_FILE"
}

# Applies dynamic configuration from environment variables.
apply_samba_config() {
    echo "Applying dynamic Samba configuration..."
    local netbios_name="${NETBIOS_NAME:-$DC_NAME}"
    local disable_netbios_val=$([ "${SAMBA_DISABLE_NETBIOS:-true}" == "true" ] && echo "yes" || echo "no")
    local realm_ucase="${DOMAIN_FQDN^^}"
    local realm_lcase="${DOMAIN_FQDN,,}"
    local workgroup="${realm_ucase%%.*}"
    local netlogon_path="/var/lib/samba/sysvol/${realm_lcase}/scripts"

    if [ -n "$DNSFORWARDER" ]; then
        set_samba_param "global" "dns forwarder" "$DNSFORWARDER"
    fi
    set_samba_param "global" "netbios name" "$netbios_name"
    set_samba_param "global" "disable netbios" "$disable_netbios_val"
    set_samba_param "global" "realm" "$realm_ucase"
    set_samba_param "global" "workgroup" "$workgroup"
    set_samba_param "netlogon" "path" "$netlogon_path"
}

# Creates directories and sets their correct permissions.
initialize_system() {
    echo "Initializing directories and permissions..."
    mkdir -p /etc/samba/config \
             /var/lib/samba/private \
             /var/lib/samba/ntp_signd \
             /var/lib/samba/winbindd_privileged

    chown -R root:root /var/lib/samba
    find /var/lib/samba -type d -exec chmod 700 {} +
    find /var/lib/samba -type f -exec chmod 600 {} +

    chmod 0750 /var/lib/samba/ntp_signd
    chmod 0750 /var/lib/samba/winbindd_privileged
    if ls /var/lib/samba/private/tls/*.pem > /dev/null 2>&1; then
        chmod 0600 /var/lib/samba/private/tls/*.pem
    fi
}

# Provisions a new domain controller if one does not already exist.
provision_domain() {
    if [ -f "$CONFIG_FILE" ]; then
        return
    fi
    echo "No Samba config file found. Provisioning new domain..."

    if [ -z "$DOMAIN_FQDN" ] || [ -z "$DNSFORWARDER" ] || [ -z "$DC_IP" ]; then
        echo "ERROR: DOMAIN_FQDN, DNSFORWARDER, and DC_IP must be set for provisioning." >&2
        exit 1
    fi

    local admin_password
    admin_password=$(cat /run/secrets/admin_password)
    if [ -z "$admin_password" ]; then
        echo "ERROR: Admin password not found in /run/secrets/admin_password" >&2
        exit 1
    fi
    
    local provision_args=(
        --use-rfc2307
        --server-role=dc
        --dns-backend=SAMBA_INTERNAL
    )

    if [ "${ALLOW_WEAK_PASSWORD:-false}" == "true" ]; then
        echo "WARNING: Allowing weak password for provisioning as per environment variable."
        provision_args+=(--option='password complexity = off')
    fi

    local realm_ucase="${DOMAIN_FQDN^^}"
    local domain_netbios="${realm_ucase%%.*}"

    samba-tool domain provision \
        "${provision_args[@]}" \
        --realm="${realm_ucase}" \
        --domain="${domain_netbios}" \
        --host-ip="${DC_IP}" \
        --adminpass="${admin_password}"

    mv /etc/samba/smb.conf "$CONFIG_FILE"
}

# Main 
if [ "$1" == "healthcheck" ]; then
    if smbclient -L localhost -U% -m SMB3 >/dev/null 2>&1; then exit 0; else exit 1; fi
fi

initialize_system
provision_domain

# Link persistent config and kerberos files to their default locations
ln -sf "$CONFIG_FILE" /etc/samba/smb.conf
if [ -f "/var/lib/samba/private/krb5.conf" ]; then
    ln -sf "/var/lib/samba/private/krb5.conf" /etc/krb5.conf
fi

apply_samba_config

# Apply verbose logging for debugging
echo "DEBUG: Forcing verbose logging to stdout..."
set_samba_param "global" "log level" "3"
set_samba_param "global" "log file" "/dev/stdout"

echo "Starting Samba..."
exec samba -i -M single --no-process-group -d 3
