# Samba Active Directory Domain Controller in Docker

This project provides a straightforward way to run a Samba-based Active Directory Domain Controller (AD DC) inside a Docker container. It uses a `macvlan` network to give the container its own unique IP address on your local network.

The setup is designed to be configurable, persistent, and easy to deploy.

## Features

-   Runs a full Samba AD DC on an **Ubuntu 24.04** base.
-   Uses **Docker Compose** for easy management.
-   Configuration is controlled via a simple `.env` file.
-   All critical data (`/var/lib/samba`) and configuration (`/etc/samba/config`) are persisted in Docker volumes.
-   Uses Docker **Secrets** to securely handle the Administrator password.
-   Assigns a dedicated IP address to the container using a **macvlan** network.

## Prerequisites

-   Docker Engine
-   Docker Compose
-   A Linux host with a network interface that supports `macvlan` (most wired interfaces do).

## Getting Started

Follow these steps to get your domain controller running.

### 1. Clone the Repository

```bash
git clone https://github.com/durankeeley/container-domaincontroller.git
cd container-domaincontroller
```

### 2. Create the Configuration File

Copy the example environment file and customize it for your network.

```bash
cp .env.example .env
```

Now, **edit the `.env` file** and fill in the values according to your network and desired domain setup.

### 3. Create the Administrator Password Secret

Create the secrets directory and the password file.

```bash
mkdir -p secrets
nano secrets/admin_password.txt
```

Now, **edit `secrets/admin_password.txt`** and the contents will be the password for your domain's `Administrator` account. This file should contain *only the password* and nothing else.

### 4. Build and Start the Container

Use Docker Compose to build the image and start the domain controller.

```bash
docker-compose up -d --build
```

The first time you run this command, the entrypoint script will automatically provision the new domain, which may take a minute. Subsequent starts will be much faster.

## Configuration

All configuration is handled by the variables in your `.env` file.

| Variable                | Description                                                                                              | Example Value              |
| ----------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------- |
| `HOST_INTERFACE`        | Your host machine's primary network interface (run `ip a` to find it).                                   | `eth0`                     |
| `SUBNET`                | Your local network's subnet in CIDR notation.                                                            | `192.168.1.0/24`           |
| `GATEWAY`               | The IP address of your network's gateway (usually your router).                                          | `192.168.1.1`              |
| `CONTAINER_IP_RANGE`    | A small, unused IP range on your network that Docker can assign IPs from.                                | `192.168.1.200/29`         |
| `MAIN_DNS_IP`           | The IP of your primary DNS server. This is used as the forwarder.                                        | `192.168.1.1`              |
| `DC_IP`                 | The static IP address you want to assign to this Domain Controller. Must be within your subnet.          | `192.168.1.89`             |
| `DC_NAME`               | The short hostname (NetBIOS name) for the Domain Controller.                                             | `DC1`                      |
| `DOMAIN_FQDN`           | The Fully Qualified Domain Name for your new Active Directory domain.                                    | `internal.mydomain.com`    |
| `SAMBA_DISABLE_NETBIOS` | Set to `false` to enable legacy NetBIOS name resolution. Defaults to `true` (recommended).               | `true`                     |

## Usage

-   **Start the Domain Controller:** `docker-compose up -d`
-   **Stop the Domain Controller:** `docker-compose down`
-   **View Logs:** `docker-compose logs -f`
-   **Force a Rebuild:** `docker-compose up -d --build`

## Testing the Domain Controller

Once the container is running, you can test it from another machine on the same network.

1.  **Configure DNS:** Set your test machine's DNS server to the IP of your DC (e.g., `192.168.1.89`).
2.  **Test Name Resolution:** (you will need to setup DNS/host files to the container IP)
    ```bash
    ping dc1.internal.mydomain.com
    nslookup internal.mydomain.com
    ```
3.  **Test Samba Shares:**
    ```bash
    # This will prompt for the administrator password you set in the secrets file.
    smbclient -L dc1.internal.mydomain.com -U Administrator
    ```
    You should see the `sysvol` and `netlogon` shares listed.
