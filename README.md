# ⭐ Sirius — Homelab Node

Primary homelab node running photo management, media serving, and machine learning workloads via Docker — accessible privately and securely over [Tailscale](https://tailscale.com/).

> **Two-node setup:** Sirius handles on-demand heavy workloads. For the always-on lightweight node (music, storage, DNS, ad blocking), see **[Corvus → cloud-audio-dns branch](../../tree/cloud-audio-dns/README.md)**.

---

## 🖥️ Hardware

| Component | Details                          |
| --------- | -------------------------------- |
| **Build** | Custom desktop                   |
| **GPU**   | NVIDIA RTX 2070 Super            |
| **RAM**   | 16GB                             |
| **OS**    | CachyOS (Arch-based)             |
| **Role**  | Primary — Photos, movies, TV, ML |

---

## 📦 Services

| Service                           | Purpose                                        | Default Port |
| --------------------------------- | ---------------------------------------------- | ------------ |
| [Immich](https://immich.app/)     | Photo & video backup and management            | `2283`       |
| [Jellyfin](https://jellyfin.org/) | Media server for movies & TV (GPU transcoding) | `8096`       |

> Immich uses PostgreSQL (with pgvecto.rs) and Valkey (Redis fork) as internal dependencies — both included in the compose stack.

> **Music playback is handled by Corvus.** Sirius's Jellyfin is for movies and TV only.

---

## ⚙️ Requirements

- A Linux machine (tested on CachyOS / Arch-based distros)
- [Docker](https://docs.docker.com/engine/install/) and Docker Compose v2
- An NVIDIA GPU with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed
- [Tailscale](https://tailscale.com/download) installed and authenticated
- External HDD or dedicated storage path for media and Immich library

---

## 🚀 Setup Guide

### 1. Clone the repository

```bash
git clone https://github.com/bentekku/homelab.git ~/server
cd ~/server
```

### 2. Configure the `.env` file

Edit `.env` and set the following:

```env
# General
TZ=Asia/Kolkata

# Immich
IMMICH_VERSION=v2.x.x              # Pin to a specific release — never use latest
UPLOAD_LOCATION=/mnt/homelab/server/data/immich/library
DB_DATA_LOCATION=./docker-data/postgres/
DB_PASSWORD=yourpassword            # Set a strong password
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

### 3. Create required directories

```bash
mkdir -p /mnt/homelab/server/config/jellyfin
mkdir -p /mnt/homelab/server/data/{immich/library,media}
```

### 4. Start the stack

```bash
docker compose up -d
```

---

## 🤖 Automation Script (`automate-homelab.sh`)

Automates mounting the external HDD and starting all containers:

```bash
mv automate-homelab.sh ~/automate-homelab.sh
chmod +x ~/automate-homelab.sh
echo "alias start-lab='~/automate-homelab.sh'" >> ~/.bashrc
source ~/.bashrc
start-lab
```

The script:

1. Detects the 1.8T external drive by size using `lsblk`
2. Mounts it to `/mnt/homelab` if not already mounted
3. Restarts all Docker containers from `~/server`

> Update the grep size pattern in the script if your drive is a different size.

---

## 🔑 Immich — First Login & Setup

On first boot, navigate to `http://100.78.247.41:2283` and complete the setup wizard to create your admin account.

---

## 🔐 Accessing Services

All services require Tailscale to be connected on your client device.

| Service  | URL                         |
| -------- | --------------------------- |
| Immich   | `http://100.78.247.41:2283` |
| Jellyfin | `http://100.78.247.41:8096` |

---

## 🔄 Updating Services

```bash
docker compose pull
docker compose up -d
docker image prune -f
```

> **Immich warning:** Always check [Immich release notes](https://github.com/immich-app/immich/releases) before updating. Pin `IMMICH_VERSION` to a specific release tag — never use `latest`.

---

## 💾 RAM Allocation

Tuned for 16GB RAM:

| Service                 | Memory Limit |
| ----------------------- | ------------ |
| immich-server           | 5000M        |
| immich-machine-learning | 4096M        |
| jellyfin                | 4000M        |
| postgres                | 512M         |
| redis (valkey)          | 256M         |

> These are **ceilings**, not reservations — services only use what they need.

---

## 📝 Notes

- Sirius is an **on-demand node** — it does not need to run 24/7. Start when needed via `start-lab`.
- **Tailscale** must be connected on both Sirius and your client device to reach services.
- For network-wide ad blocking, DNS management, music playback, and always-on file storage — see **[Corvus](../../tree/cloud-audio-dns/README.md)**.
