# 🏠 Homelab

Personal homelab server running **Immich**, **Jellyfin**, **Feishin**, and **OpenCloud** via Docker — accessible privately and securely over [Tailscale](https://tailscale.com/).

---

## 📦 Services

| Service                                       | Purpose                                           | Default Port                 |
| --------------------------------------------- | ------------------------------------------------- | ---------------------------- |
| [Immich](https://immich.app/)                 | Photo & video backup and management               | `2283`                       |
| [Jellyfin](https://jellyfin.org/)             | Media server for movies, TV, music                | `8096`                       |
| [Feishin](https://github.com/jeffvli/feishin) | Music player frontend for Jellyfin                | `9180`                       |
| [OpenCloud](https://opencloud.eu/)            | Self-hosted cloud storage (Nextcloud alternative) | `9200` (via Tailscale HTTPS) |

> **Note:** Immich uses PostgreSQL (with pgvecto.rs) and Valkey (Redis fork) as internal dependencies — both are included in the compose stack.

---

## ⚙️ Requirements

- A Linux machine (tested on CachyOS / Arch-based distros)
- [Docker](https://docs.docker.com/engine/install/) and Docker Compose v2
- An NVIDIA GPU (for hardware-accelerated transcoding and Immich ML) with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed
- [Tailscale](https://tailscale.com/download) installed and authenticated on the server
- An external HDD or a dedicated storage path for media and Immich library

---

## 🚀 Setup Guide

### 1. Clone the repository

```bash
git clone <your-repo-url> ~/server
cd ~/server
```

### 2. Configure the `.env` file

Copy `.env.example` to `.env` (if provided) or edit `.env` directly. Replace the following values:

```env
# Immich
IMMICH_VERSION=v2.x.x        # Pin to a specific release. Check release notes before updating.
UPLOAD_LOCATION=/mnt/homelab/server/data/immich/library   # Where Immich stores photos/videos
DB_DATA_LOCATION=./docker-data/postgres/                  # Preferably on SSD for performance
DB_PASSWORD=yourpassword      # Set a strong password

# Feishin
FEISHIN_SERVER_NAME=Jellyfin  # Display name for the server (e.g. Jellyfin, Navidrome)
FEISHIN_SERVER_TYPE=jellyfin  # Server type: jellyfin or navidrome
FEISHIN_SERVER_URL=http://<tailscale-ip>:8096             # Your Jellyfin URL via Tailscale IP
FEISHIN_SERVER_LOCK=true      # Locks server settings for users (recommended)

# OpenCloud
OC_CONFIG_DIR=/mnt/homelab/server/config/opencloud
OC_DATA_DIR=/mnt/homelab/server/data/opencloud
OC_TAILSCALE_HOSTNAME=yourserver.hyena-fujita.ts.net      # Run: tailscale status
OC_URL=https://yourserver.hyena-fujita.ts.net             # Must use https://
```

> **Tip:** Run `tailscale status` to find your server's Tailscale hostname and IP.

### 3. Create required directories

```bash
mkdir -p /mnt/homelab/server/{config,data}/{jellyfin,opencloud}
mkdir -p /mnt/homelab/server/data/{immich/library,media}
```

### 4. Set up Tailscale HTTPS for OpenCloud

OpenCloud requires HTTPS for its OIDC authentication to work correctly. Tailscale's built-in serve feature handles this cleanly without needing a reverse proxy:

```bash
# Allow Tailscale serve without sudo in future (run once)
sudo tailscale set --operator=$USER

# Expose OpenCloud over HTTPS via Tailscale
sudo tailscale serve --bg http://localhost:9200
```

This makes OpenCloud accessible at `https://yourserver.hyena-fujita.ts.net` with a valid Tailscale-issued certificate — no self-signed cert warnings.

> **Important:** OpenCloud uses `network_mode: host` in the compose file. This is required so it can reach the Tailscale interface for OIDC token verification. Do not remove this.

### 5. Start the stack

```bash
docker compose up -d
```

Or use the automation script (see below).

---

## 🤖 Automation Script (`automate-homelab.sh`)

The script automates mounting your external HDD and starting all containers. Move it somewhere convenient:

```bash
mv automate-homelab.sh ~/automate-homelab.sh
chmod +x ~/automate-homelab.sh
```

Add an alias for quick access:

```bash
echo "alias start-lab='~/automate-homelab.sh'" >> ~/.bashrc
source ~/.bashrc
```

Then just run:

```bash
start-lab
```

The script:

1. Detects your 1.8T external drive by size using `lsblk`
2. Mounts it to `/mnt/homelab` if not already mounted
3. Restarts all Docker containers from `~/server`

> **Note:** The drive detection searches by size (`1.8T`). If your drive is a different size, update the grep pattern in the script accordingly.

---

## 🔐 Accessing Your Services

All services are accessible via Tailscale — you must be connected to your Tailscale network on any device to reach them.

| Service   | URL                            |
| --------- | ------------------------------ |
| Immich    | `http://<tailscale-ip>:2283`   |
| Jellyfin  | `http://<tailscale-ip>:8096`   |
| Feishin   | `http://<tailscale-ip>:9180`   |
| OpenCloud | `https://<tailscale-hostname>` |

Find your server's Tailscale IP and hostname:

```bash
tailscale status
```

---

## 🔑 OpenCloud — First Login & Setup

On first boot, OpenCloud generates a random admin password. Retrieve it from the logs:

```bash
docker logs opencloud 2>&1 | grep -A3 "generated OpenCloud Config"
```

Log in at `https://yourserver.hyena-fujita.ts.net` with:

- **Username:** `admin`
- **Password:** _(from logs above)_

**To change the admin password:**

Go to avatar (top right) → **Preferences** → scroll to the password section.

Alternatively, reset it via CLI (container must be stopped first):

```bash
docker stop opencloud
docker run --rm -it \
  -v /mnt/homelab/server/config/opencloud:/etc/opencloud \
  -v /mnt/homelab/server/data/opencloud:/var/lib/opencloud \
  opencloudeu/opencloud-rolling:latest idm resetpassword
docker start opencloud
```

**To create user accounts:**

Grid icon (top left) → **Admin Settings** → **Users** → **Create User**. Each user gets isolated personal storage.

---

## 🔄 Updating Services

```bash
# Pull latest images
docker compose pull

# Restart with new images (zero-downtime friendly)
docker compose up -d

# Clean up old image versions
docker image prune -f
```

> **Immich warning:** Always check the [Immich release notes](https://github.com/immich-app/immich/releases) before updating — it is under active development and occasionally has breaking changes. Pin `IMMICH_VERSION` to a specific release tag rather than using `latest`.

---

## 💾 RAM Allocation

The stack is tuned for a 16GB RAM system:

| Service                 | Memory Limit |
| ----------------------- | ------------ |
| immich-server           | 5000M        |
| immich-machine-learning | 4096M        |
| jellyfin                | 4000M        |
| opencloud               | 1024M        |
| feishin                 | 512M         |
| postgres                | 512M         |
| redis (valkey)          | 256M         |

These are **ceilings**, not reservations — services only use what they need.

---

## 📝 Notes

- **Feishin** is in maintenance mode as of late 2024. Its successor is [Audioling](https://github.com/audioling/audioling) — worth watching.
- **OpenCloud** runs with `network_mode: host` due to Tailscale networking requirements. This is intentional and safe for a private homelab.
- **Tailscale serve** must be running for OpenCloud to be accessible. It does not persist across reboots automatically — add it to your startup routine or use `automate-homelab.sh`.
