# argon

Home server stack running on a Raspberry Pi. All services are managed with Docker Compose and deployed via a single script.

## Services

| Service | Port | Description |
|---|---|---|
| [Pi-hole](#pi-hole) | 53, 8443 | Network-wide ad blocking and DNS |
| [Home Assistant](#home-assistant) | 8123 (host) | Home automation hub |
| [Z-Wave JS UI](#z-wave-js-ui) | 8091, 3000 | Z-Wave device management |
| [Caddy](#caddy) | 80, 443 | HTTPS reverse proxy |
| [GMC-300](#gmc-300) | — | Geiger counter → Home Assistant |
| [Sentinel](#sentinel) | — | Home sentry robot → Home Assistant |
| [Kiwix](#kiwix) | 8888 | Offline Wikipedia |
| [Maps](#maps) | 8090 | Offline OpenStreetMap viewer |
| [Plex](#plex) | 32400 (host) | Media server |
| [DDNS](#ddns) | — | Dynamic DNS updater |

---

### Pi-hole

Network-wide DNS-based ad blocker. Also serves as the primary DNS resolver for the LAN (upstream: Cloudflare 1.1.1.1).

Web UI available at `https://<host>:8443`.

### Home Assistant

Home automation platform. Runs with `network_mode: host` and `privileged: true` to allow device discovery (mDNS, Bluetooth, etc.).

Config persisted in `data/homeassistant/`.

### Z-Wave JS UI

Web UI and WebSocket server for the Z-Wave USB stick. Provides the Z-Wave JS integration used by Home Assistant.

- UI: `http://<host>:8091`
- WebSocket: `ws://<host>:3000`

Z-Wave network keys are passed in via environment variables (see `.env`).

### Caddy

Automatic HTTPS reverse proxy. Proxies external HTTPS traffic to Home Assistant on the internal network. Config in `caddy/Caddyfile`.

Requires a public domain name pointing to the server (managed by the DDNS service).

### GMC-300

Custom container that reads radiation data from a [GQ GMC-300/320](https://www.gqelectronicsllc.com/) Geiger counter over USB serial and pushes it to Home Assistant via the REST API every 60 seconds.

Source in `gmc300/`. The C binary (`gmc320`) reads a single measurement from the device and outputs JSON. `run.sh` loops this and POSTs to the HA states API.

Requires a long-lived access token from Home Assistant (`HA_TOKEN`).

### Sentinel

Home sentry robot integration. Source: [github.com/arudyk/sentinel](https://github.com/arudyk/sentinel).

`deploy.sh` automatically pulls the latest code from the sentinel repo and installs:
- `data/homeassistant/custom_components/sentinel/` — HA custom integration (camera, drive buttons, battery sensors, speed control)
- `data/homeassistant/www/sentinel-card.js` — Lovelace card with live camera feed and D-pad controls

After deploy, Home Assistant is restarted to pick up any integration changes. To add the robot to HA for the first time, go to **Settings → Devices & Services → Add Integration** and search for **Sentinel**, then enter the robot's IP and port (default `8080`).

### Kiwix

Serves offline `.zim` archives (e.g. Wikipedia). Place `.zim` files in `data/kiwix/` and the container will serve all of them.

Web UI: `http://<host>:8888`

### Maps

Offline map viewer using [MapLibre GL JS](https://maplibre.org/) and [PMTiles](https://docs.protomaps.com/pmtiles/). Tiles are served directly from `.pmtiles` files via HTTP range requests — no tile server required.

**Features:**
- US and Europe region toggle
- Address search via [Nominatim](https://nominatim.org/) (requires internet; works offline if not needed)
- Right-click to get GPS coordinates with a copy button
- Distance measurement tool (📏)

**Tile files** (not included in this repo — large binary files):

```bash
# Install pmtiles CLI
go install github.com/protomaps/go-pmtiles/...@latest

# Download US tiles (~8 GB)
pmtiles extract https://build.protomaps.com/<date>.pmtiles data/tiles/us.pmtiles \
  --bbox=-126,24,-66,50 --maxzoom=14

# Download Europe tiles (~23 GB)
pmtiles extract https://build.protomaps.com/<date>.pmtiles data/tiles/europe.pmtiles \
  --bbox=-25,34,45,72 --maxzoom=14
```

Check [build.protomaps.com](https://build.protomaps.com) for the latest build filename.

All JS/CSS assets and map fonts/sprites are downloaded locally by `deploy.sh` on first run (no CDN required once deployed).

### Plex

Media server. Expects media mounted at `/mnt/media` on the host (e.g. an external SSD).

For initial setup, a claim token from [plex.tv/claim](https://plex.tv/claim) must be set in `PLEX_CLAIM`. After first run the token is no longer needed. If setting up without a claim token, use an SSH tunnel:

```bash
ssh -L 32400:localhost:32400 user@<host>
# then open http://localhost:32400/web
```

### DDNS

Lightweight Alpine container that updates a [Namecheap Dynamic DNS](https://www.namecheap.com/support/knowledgebase/article.aspx/29/11/how-to-dynamically-update-the-hosts-ip-with-an-a-record/) A record every 30 minutes with the server's current public IP.

---

## Setup

### Prerequisites

- Raspberry Pi (or any Linux host) with Docker and Docker Compose
- USB Z-Wave stick (e.g. Zooz ZST10 700)
- GQ GMC-300/320 Geiger counter (optional)
- External storage mounted at `/mnt/media` (optional, for Plex)

### Deploy

```bash
cp .env.example .env.argon   # fill in secrets
./deploy.sh
```

`deploy.sh` will:
1. Download map JS/CSS assets locally if missing
2. Download Protomaps fonts and sprites if missing
3. `rsync` the project to the Pi
4. Copy `.env.argon` → `.env` on the remote
5. Pull the latest Sentinel HA integration from its repo and deploy to `data/homeassistant/`
6. Restart Home Assistant

The Pi address and remote directory are configured at the top of `deploy.sh`.

---

## Environment Variables

Copy `.env.example` to `.env.argon` and fill in the values.

```bash
# Pi-hole web UI password
PIHOLE_PASSWORD=your_pihole_password

# Namecheap Dynamic DNS
DDNS_DOMAIN=yourdomain.com
DDNS_PASSWORD=your_namecheap_ddns_password

# Z-Wave network keys (generate with: openssl rand -hex 16)
ZWAVE_KEY_S0_Legacy=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ZWAVE_KEY_S2_Unauthenticated=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ZWAVE_KEY_S2_Authenticated=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ZWAVE_KEY_S2_AccessControl=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ZWAVE_LR_KEY_S2_Authenticated=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ZWAVE_LR_KEY_S2_AccessControl=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Home Assistant long-lived access token for GMC-300 integration
# Create at: Settings → Profile → Long-lived access tokens
GMC300_HA_TOKEN=your_home_assistant_token

# Plex claim token from https://plex.tv/claim (only needed on first run)
PLEX_CLAIM=
```

---

## Data Layout

```
data/
├── pihole/         # Pi-hole config and DNS records
├── homeassistant/  # Home Assistant config
├── zwave-js-ui/    # Z-Wave JS UI store
├── caddy/          # Caddy TLS certificates and config cache
├── kiwix/          # .zim archive files
├── tiles/          # PMTiles files (us.pmtiles, europe.pmtiles)
└── plex/           # Plex metadata and transcoding cache
```

All of `data/` is excluded from version control.
