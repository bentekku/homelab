# 🐦‍⬛ Corvus — Homelab Node

Always-on lightweight homelab node running music playback, file storage, network-wide ad blocking, and DNS via Docker — accessible privately and securely over [Tailscale](https://tailscale.com/).

> **Two-node setup:** Corvus handles always-on lightweight services. For the on-demand primary node (photos, movies, TV, ML), see **[Sirius → main branch](../../tree/main/README.md)**.

---

## 🖥️ Hardware

| Component   | Details                                       |
| ----------- | --------------------------------------------- |
| **Build**   | HP 245 G4 Notebook                            |
| **GPU**     | AMD Radeon R5 (integrated, no dedicated VRAM) |
| **RAM**     | 8GB                                           |
| **Storage** | ~500GB HDD (internal)                         |
| **OS**      | Ubuntu Server 26.04 LTS                       |
| **Role**    | Always-on — Music, storage, DNS, ad blocking  |

> Corvus has no dedicated GPU. Docker hardware transcoding is not configured — CPU transcoding is sufficient for music-only Jellyfin. All data lives on the internal HDD under `/opt/homelab`.

---

## 📦 Services

| Service                                       | Purpose                                   | Default Port                  |
| --------------------------------------------- | ----------------------------------------- | ----------------------------- |
| [Jellyfin](https://jellyfin.org/)             | Music-only media server (CPU transcoding) | `8096`                        |
| [Feishin](https://github.com/jeffvli/feishin) | Music player frontend for Jellyfin        | `9180`                        |
| [OpenCloud](https://opencloud.eu/)            | Self-hosted cloud storage                 | `9200` (via Tailscale HTTPS)  |
| [Pi-hole](https://pi-hole.net/)               | Network-wide ad blocking + DNS            | `53` (DNS) · `80` (dashboard) |

> Pi-hole runs with `network_mode: host` for reliable port 53 binding. OpenCloud also uses `network_mode: host` for Tailscale OIDC compatibility.

---

## ⚙️ Requirements

- Ubuntu Server 26.04 LTS
- [Docker](https://docs.docker.com/engine/install/) and Docker Compose v2
- [Tailscale](https://tailscale.com/download) installed and authenticated
- A **static LAN IP** assigned to Corvus via DHCP reservation on your router — required for Pi-hole DNS
- Samba (`smbd`) installed for file sharing

---

## 🚀 Setup Guide

### 1. Clone and switch to this branch

```bash
git clone https://github.com/bentekku/homelab.git ~/server
cd ~/server
git checkout cloud-audio-dns
```

### 2. Configure the `.env` file

Edit `.env` and update the following:

```env
# General
TZ=Asia/Kolkata
CORVUS_LAN_IP=192.168.1.201        # Corvus's static LAN IP

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
OC_URL=https://corvus.hyena-fujita.ts.net    # Update after: tailscale status

# Pi-hole
PIHOLE_WEBPASSWORD=yourpassword
PIHOLE_CONFIG_DIR=/opt/homelab/config/pihole
PIHOLE_UPSTREAM_DNS_1=1.1.1.1
PIHOLE_UPSTREAM_DNS_2=1.0.0.1
```

### 3. Create required directories

```bash
sudo mkdir -p /opt/homelab/{config,data}/{jellyfin,opencloud}
sudo mkdir -p /opt/homelab/config/pihole/{etc-pihole,etc-dnsmasq.d}
sudo mkdir -p /opt/homelab/data/music
sudo chown -R $USER:$USER /opt/homelab
```

### 4. Fix systemd-resolved port conflict

Ubuntu Server occupies port 53 by default via `systemd-resolved`. Pi-hole cannot bind until this is disabled:

```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

> Do this **before** `docker compose up` or Pi-hole will fail to start.

### 5. Assign a static LAN IP

On your router, go to **Local Network → LAN → DHCP** and add a DHCP reservation for Corvus's MAC address. Update `CORVUS_LAN_IP` in `.env` to match.

Find Corvus's MAC address:

```bash
ip link show eno1
```

### 6. Install Tailscale and set up OpenCloud HTTPS

```bash
curl -fsSL https://tailscale.com/install.sh | sudo sh
sudo tailscale up
sudo tailscale set --operator=$USER
tailscale serve --bg http://localhost:9200
```

Run `tailscale status` to confirm Corvus's Tailscale hostname and update `OC_URL` in `.env`.

> `tailscale serve` must be running for OpenCloud to be accessible. It does not persist across reboots — add it to your startup routine.

### 7. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

Log out and back in, then verify:

```bash
docker run hello-world
```

### 8. Start the stack

```bash
docker compose up -d
```

---

## 🔒 Pi-hole — Network & Remote Ad Blocking

Pi-hole runs with `network_mode: host` and `dns.listeningMode = ALL` to accept queries from both LAN and Tailscale interfaces.

### Known fix — listening mode

By default Pi-hole's listening mode is `LOCAL`, which rejects queries from Tailscale's `100.x.x.x` range. This is set permanently via the compose environment:

```yaml
- FTLCONF_dns_listeningMode=ALL
```

If Pi-hole stops responding over Tailscale after a reinstall, re-apply manually:

```bash
docker exec pihole pihole-FTL --config dns.listeningMode ALL
docker restart pihole
```

### Router-level DNS (LAN)

On your router go to **Local Network → DNS** and set:

```
Primary DNS:    192.168.1.201     ← Pi-hole (Corvus)
Secondary DNS:  1.1.1.1           ← Cloudflare fallback
```

All devices on your home network will have ads blocked automatically.

### Cellular ad blocking via Tailscale

To block ads on mobile data without an exit node (DNS queries only):

1. Open [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns)
2. Add nameserver → enter Corvus's Tailscale IP (`100.73.115.57`)
3. Enable **"Override DNS servers"**

Every Tailscale-connected device now routes DNS through Pi-hole regardless of network.

### Pi-hole Dashboard

```
http://192.168.1.201/admin
```

> Dashboard is on port 80 (not 8080) because Pi-hole uses `network_mode: host` — no port mapping is applied.

---

## 🔑 OpenCloud — First Login & Setup

On first boot, retrieve the auto-generated admin password:

```bash
docker logs opencloud 2>&1 | grep -i "password"
```

If nothing is returned (config already existed), reset via CLI:

```bash
docker stop opencloud
docker run --rm -it \
  -v /opt/homelab/config/opencloud:/etc/opencloud \
  -v /opt/homelab/data/opencloud:/var/lib/opencloud \
  opencloudeu/opencloud-rolling:latest idm resetpassword
docker start opencloud
```

Log in at `https://corvus.hyena-fujita.ts.net` with username `admin`.

**To create user accounts:** Grid icon (top left) → **Admin Settings** → **Users** → **Create User**.

---

## 📁 Samba — File Sharing

Corvus exposes three Samba shares for easy file access from any device on the LAN or over Tailscale.

### Installation

```bash
sudo apt install -y samba
sudo smbpasswd -a <your-username>
sudo systemctl enable smbd
sudo systemctl start smbd
```

### Shares

| Share              | Path                      |
| ------------------ | ------------------------- |
| `\\corvus\music`   | `/opt/homelab/data/music` |
| `\\corvus\homelab` | `/opt/homelab`            |
| `\\corvus\home`    | `/home/<your-username>`   |

### Accessing shares

**Linux (file manager):**

```
smb://192.168.1.201       ← LAN
smb://100.73.115.57       ← Tailscale (anywhere)
```

**Windows (File Explorer address bar):**

```
\\192.168.1.201           ← LAN
\\100.73.115.57           ← Tailscale (anywhere)
```

**Android:** Use MiXplorer or FX File Explorer → add SMB connection:

```
Host: 192.168.1.201 (or 100.73.115.57 over Tailscale)
Username: <your-username>
Password: <samba password>
```

### Bulk transfer from Sirius

To transfer files from Sirius to Corvus over LAN using rsync:

```bash
rsync -avh --progress /path/to/source/ <username>@192.168.1.201:/opt/homelab/data/music/
```

---

## 🔐 Accessing Services

All services require Tailscale to be connected on your client device.

| Service           | URL                                  |
| ----------------- | ------------------------------------ |
| Jellyfin          | `http://100.73.115.57:8096`          |
| Feishin           | `http://100.73.115.57:9180`          |
| OpenCloud         | `https://corvus.hyena-fujita.ts.net` |
| Pi-hole Dashboard | `http://192.168.1.201/admin`         |

---

## 🔄 Updating Services

```bash
docker compose pull
docker compose up -d
docker image prune -f
```

---

## 💾 RAM Allocation

Tuned for 8GB RAM:

| Service   | Memory Limit                       |
| --------- | ---------------------------------- |
| jellyfin  | 512M                               |
| opencloud | 768M                               |
| feishin   | 256M                               |
| pihole    | 256M (host network, no hard limit) |

> Corvus runs comfortably under 2.5GB total at full load, leaving ample headroom.

---

## 🔥 UFW Firewall

UFW is active on Corvus with the following rules:

| Port    | Protocol  | Service           |
| ------- | --------- | ----------------- |
| 22      | TCP       | SSH               |
| 53      | TCP + UDP | Pi-hole DNS       |
| 80      | TCP       | Pi-hole dashboard |
| 137-138 | UDP       | Samba (NetBIOS)   |
| 139     | TCP       | Samba             |
| 445     | TCP       | Samba             |
| 8096    | TCP       | Jellyfin          |
| 9180    | TCP       | Feishin           |
| 9200    | TCP       | OpenCloud         |
| 41641   | UDP       | Tailscale         |

> Note: Docker bypasses UFW by writing directly to iptables. UFW rules are a secondary layer — Tailscale is the primary access control for remote services.

---

## 📝 Notes

- **Feishin** is in maintenance mode as of late 2024. Its successor is [Audioling](https://github.com/audioling/audioling) — worth watching.
- **OpenCloud** and **Pi-hole** both use `network_mode: host` — no port mappings are defined for these services in the compose file. This is intentional.
- **Pi-hole requires a static LAN IP.** If Corvus's IP changes, DNS breaks network-wide. Always use a DHCP reservation, never rely on dynamic assignment.
- **Samba port** must be allowed in UFW: `sudo ufw allow samba`
- For on-demand heavy workloads (photos, movies, TV, ML) — see **[Sirius](../../tree/main/README.md)**.
