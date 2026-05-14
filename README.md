# 🏠 Homelab

A two-node personal homelab running self-hosted services via Docker — accessible privately and securely over [Tailscale](https://tailscale.com/).

---

## 🖥️ Nodes

| Node       | Hardware                                         | OS                      | Role                              |
| ---------- | ------------------------------------------------ | ----------------------- | --------------------------------- |
| **Sirius** | Custom build · NVIDIA RTX 2070 Super · 16GB RAM  | CachyOS (Arch-based)    | Primary — Photos, media, ML       |
| **Corvus** | HP 245 G4 · AMD Radeon R5 (iGPU) · 8GB RAM · HDD | Ubuntu Server 26.04 LTS | Lightweight — Music, storage, DNS |

> Sirius is the on-demand powerhouse. Corvus runs 24/7 as a low-power always-on node for music, file storage, and network-wide ad blocking.

---

## 📦 Services

### Sirius (`main` branch)

| Service                                       | Purpose                                        | Default Port                 |
| --------------------------------------------- | ---------------------------------------------- | ---------------------------- |
| [Immich](https://immich.app/)                 | Photo & video backup and management            | `2283`                       |
| [Jellyfin](https://jellyfin.org/)             | Media server for movies & TV (GPU transcoding) | `8096`                       |
| [Feishin](https://github.com/jeffvli/feishin) | Music player frontend for Jellyfin             | `9180`                       |
| [OpenCloud](https://opencloud.eu/)            | Self-hosted cloud storage                      | `9200` (via Tailscale HTTPS) |

> Immich uses PostgreSQL (with pgvecto.rs) and Valkey (Redis fork) as internal dependencies — both included in the compose stack.

### Corvus (`cloud-audio-dns` branch)

| Service                                       | Purpose                                   | Default Port                    |
| --------------------------------------------- | ----------------------------------------- | ------------------------------- |
| [Jellyfin](https://jellyfin.org/)             | Music-only media server (CPU transcoding) | `8096`                          |
| [Feishin](https://github.com/jeffvli/feishin) | Music player frontend for Jellyfin        | `9180`                          |
| [OpenCloud](https://opencloud.eu/)            | Self-hosted cloud storage                 | `9200` (via Tailscale HTTPS)    |
| [Pi-hole](https://pi-hole.net/)               | Network-wide ad blocking + DNS            | `53` (DNS) · `8080` (dashboard) |

> Corvus has no dedicated GPU. Jellyfin runs CPU-only transcoding — sufficient for music. Pi-hole doubles as the LAN DNS server and, via Tailscale, blocks ads on cellular too.

---

## ⚙️ Requirements

### Sirius

- A Linux machine (tested on CachyOS / Arch-based distros)
- [Docker](https://docs.docker.com/engine/install/) and Docker Compose v2
- An NVIDIA GPU with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Tailscale](https://tailscale.com/download) installed and authenticated
- External HDD or dedicated storage path for media and Immich library

### Corvus

- Ubuntu Server 26.04 LTS
- [Docker](https://docs.docker.com/engine/install/) and Docker Compose v2
- [Tailscale](https://tailscale.com/download) installed and authenticated
- A **static LAN IP** assigned to Corvus (via DHCP reservation on router) — required for Pi-hole DNS

---

## 🚀 Setup Guide

### Sirius (`main` branch)

#### 1. Clone the repository

```bash
git clone <your-repo-url> ~/server
cd ~/server
```

#### 2. Configure the `.env` file

```env
# Immich
IMMICH_VERSION=v2.x.x
UPLOAD_LOCATION=/mnt/homelab/server/data/immich/library
DB_DATA_LOCATION=./docker-data/postgres/
DB_PASSWORD=yourpassword

# Feishin
FEISHIN_SERVER_NAME=Jellyfin
FEISHIN_SERVER_TYPE=jellyfin
FEISHIN_SERVER_URL=http://<tailscale-ip>:8096
FEISHIN_SERVER_LOCK=true

# OpenCloud
OC_CONFIG_DIR=/mnt/homelab/server/config/opencloud
OC_DATA_DIR=/mnt/homelab/server/data/opencloud
OC_TAILSCALE_HOSTNAME=sirius.hyena-fujita.ts.net
OC_URL=https://sirius.hyena-fujita.ts.net
```

> Run `tailscale status` to find your Tailscale hostname and IP.

#### 3. Create required directories

```bash
mkdir -p /mnt/homelab/server/{config,data}/{jellyfin,opencloud}
mkdir -p /mnt/homelab/server/data/{immich/library,media}
```

#### 4. Set up Tailscale HTTPS for OpenCloud

```bash
sudo tailscale set --operator=$USER
sudo tailscale serve --bg http://localhost:9200
```

#### 5. Start the stack

```bash
docker compose up -d
```

---

### Corvus (`cloud-audio-dns` branch)

#### 1. Clone and switch branch

```bash
git clone <your-repo-url> ~/server
cd ~/server
git checkout cloud-audio-dns
```

#### 2. Configure the `.env` file

```env
# General
TZ=Asia/Kolkata
CORVUS_LAN_IP=192.168.1.100        # Corvus's static LAN IP — check your router's DHCP table

# Jellyfin
JELLYFIN_CONFIG_DIR=/opt/homelab/config/jellyfin
JELLYFIN_MUSIC_DIR=/opt/homelab/data/music

# Feishin
FEISHIN_SERVER_NAME=Jellyfin
FEISHIN_SERVER_TYPE=jellyfin
FEISHIN_SERVER_URL=http://localhost:8096
FEISHIN_SERVER_LOCK=true

# OpenCloud
OC_CONFIG_DIR=/opt/homelab/config/opencloud
OC_DATA_DIR=/opt/homelab/data/opencloud
OC_URL=https://corvus.hyena-fujita.ts.net    # Update after tailscale status

# Pi-hole
PIHOLE_WEBPASSWORD=yourpassword
PIHOLE_CONFIG_DIR=/opt/homelab/config/pihole
PIHOLE_UPSTREAM_DNS_1=1.1.1.1
PIHOLE_UPSTREAM_DNS_2=1.0.0.1
```

#### 3. Create required directories

```bash
sudo mkdir -p /opt/homelab/{config,data}/{jellyfin,opencloud}
sudo mkdir -p /opt/homelab/config/pihole/{etc-pihole,etc-dnsmasq.d}
sudo mkdir -p /opt/homelab/data/music

# Give your user ownership so Docker doesn't need root for volume mounts
sudo chown -R $USER:$USER /opt/homelab
```

#### 4. Fix systemd-resolved port conflict (Pi-hole prerequisite)

Ubuntu Server uses `systemd-resolved` which occupies port 53 by default. Pi-hole cannot bind until this is disabled:

```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

> Do this **before** `docker compose up`, or Pi-hole will fail to start.

#### 5. Assign Corvus a static LAN IP

On your router (e.g. ZTE Airtel Xtreme — usually at `192.168.0.1`), go to **Advanced → DHCP** and add a reservation for Corvus's MAC address. Update `CORVUS_LAN_IP` in `.env` to match.

#### 6. Set up Tailscale HTTPS for OpenCloud

```bash
sudo tailscale set --operator=$USER
sudo tailscale serve --bg http://localhost:9200
```

Then run `tailscale status` to confirm Corvus's hostname and update `OC_URL` in `.env`.

#### 7. Start the stack

```bash
docker compose up -d
```

---

## 🔒 Pi-hole — Network & Remote Ad Blocking

### Router-level DNS (LAN)

Set **Corvus's static LAN IP** as the primary DNS server in your router settings:

- ZTE Airtel Xtreme: `192.168.0.1` → Advanced → DNS → Primary DNS → `<CORVUS_LAN_IP>`

All devices on your home network will have ads blocked automatically — no per-device setup needed.

### Cellular ad blocking via Tailscale DNS Override

To block ads on your phone even on mobile data (no exit node required — only DNS queries are tunnelled):

1. Open [Tailscale Admin Console](https://login.tailscale.com/admin/dns)
2. Go to **DNS → Nameservers → Add nameserver**
3. Enter Corvus's Tailscale IP (find it via `tailscale status` on Corvus)
4. Enable **"Override local DNS"**

Every Tailscale-connected device now routes DNS through Pi-hole, regardless of network.

### Pi-hole Dashboard

```
http://<CORVUS_LAN_IP>:8080/admin
```

---

## 🔑 OpenCloud — First Login & Setup

On first boot, OpenCloud generates a random admin password. Retrieve it:

```bash
docker logs opencloud 2>&1 | grep -A3 "generated OpenCloud Config"
```

Log in at `https://<node>.hyena-fujita.ts.net` with username `admin` and the password from above.

**To reset the admin password via CLI:**

```bash
docker stop opencloud
docker run --rm -it \
  -v <OC_CONFIG_DIR>:/etc/opencloud \
  -v <OC_DATA_DIR>:/var/lib/opencloud \
  opencloudeu/opencloud-rolling:latest idm resetpassword
docker start opencloud
```

**To create user accounts:** Grid icon (top left) → **Admin Settings** → **Users** → **Create User**.

---

## 🔐 Accessing Services

All services require Tailscale to be connected.

### Sirius

| Service   | URL                                  |
| --------- | ------------------------------------ |
| Immich    | `http://<sirius-tailscale-ip>:2283`  |
| Jellyfin  | `http://<sirius-tailscale-ip>:8096`  |
| Feishin   | `http://<sirius-tailscale-ip>:9180`  |
| OpenCloud | `https://sirius.hyena-fujita.ts.net` |

### Corvus

| Service           | URL                                  |
| ----------------- | ------------------------------------ |
| Jellyfin          | `http://<corvus-tailscale-ip>:8096`  |
| Feishin           | `http://<corvus-tailscale-ip>:9180`  |
| OpenCloud         | `https://corvus.hyena-fujita.ts.net` |
| Pi-hole Dashboard | `http://<corvus-lan-ip>:8080/admin`  |

---

## 🔄 Updating Services

```bash
docker compose pull
docker compose up -d
docker image prune -f
```

> **Immich warning (Sirius only):** Always check [Immich release notes](https://github.com/immich-app/immich/releases) before updating. Pin `IMMICH_VERSION` to a specific tag rather than `latest`.

---

## 💾 RAM Allocation

### Sirius (16GB)

| Service                 | Memory Limit |
| ----------------------- | ------------ |
| immich-server           | 5000M        |
| immich-machine-learning | 4096M        |
| jellyfin                | 4000M        |
| opencloud               | 1024M        |
| feishin                 | 512M         |
| postgres                | 512M         |
| redis (valkey)          | 256M         |

### Corvus (8GB)

| Service   | Memory Limit |
| --------- | ------------ |
| jellyfin  | 512M         |
| opencloud | 768M         |
| feishin   | 256M         |
| pihole    | 256M         |

> These are **ceilings**, not reservations. Corvus runs comfortably under 2.5GB total at full load, leaving ample headroom.

---

## 🤖 Automation Script — Sirius (`automate-homelab.sh`)

```bash
mv automate-homelab.sh ~/automate-homelab.sh
chmod +x ~/automate-homelab.sh
echo "alias start-lab='~/automate-homelab.sh'" >> ~/.bashrc
source ~/.bashrc
start-lab
```

The script detects your 1.8T external drive by size, mounts it to `/mnt/homelab`, and restarts all containers. Update the grep size pattern if your drive is a different size.

> Corvus does not use an external drive — music and data live on the internal HDD.

---

## 📝 Notes

- **Feishin** is in maintenance mode as of late 2024. Its successor is [Audioling](https://github.com/audioling/audioling) — worth watching.
- **OpenCloud** runs with `network_mode: host` on both nodes due to Tailscale networking requirements for OIDC. This is intentional and safe for a private homelab.
- **Tailscale serve** must be running for OpenCloud to be accessible. It does not persist across reboots automatically — add it to your startup routine.
- **Corvus has no dedicated GPU.** AMD Radeon R5 is an integrated GPU sharing system RAM. Hardware transcoding via Docker is not configured. For music-only Jellyfin use, CPU transcoding is more than sufficient.
- **Pi-hole requires a static LAN IP on Corvus.** If Corvus's IP changes, DNS breaks for the whole network. Always use a DHCP reservation.
