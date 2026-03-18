#!/usr/bin/env bash
set -euo pipefail

REMOTE="andriy@192.168.1.137"
REMOTE_DIR="~/argon"

# Download map JS/CSS assets if missing
if [ ! -f "map/assets/maplibre-gl.js" ]; then
  echo "Downloading map JS/CSS assets..."
  mkdir -p map/assets
  wget -q "https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.js"              -O map/assets/maplibre-gl.js
  wget -q "https://unpkg.com/maplibre-gl@4/dist/maplibre-gl-csp-worker.js"  -O map/assets/maplibre-gl-csp-worker.js
  wget -q "https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.css"             -O map/assets/maplibre-gl.css
  wget -q "https://unpkg.com/pmtiles@3/dist/pmtiles.js"                      -O map/assets/pmtiles.js
  wget -q "https://unpkg.com/@protomaps/basemaps@5/dist/basemaps.js"         -O map/assets/basemaps.js
  wget -q "https://unpkg.com/@maplibre/maplibre-gl-geocoder@1/dist/maplibre-gl-geocoder.js"  -O map/assets/maplibre-gl-geocoder.js
  wget -q "https://unpkg.com/@maplibre/maplibre-gl-geocoder@1/dist/maplibre-gl-geocoder.css" -O map/assets/maplibre-gl-geocoder.css
fi

# Download Protomaps fonts and sprites if missing
if [ ! -d "map/fonts" ]; then
  echo "Downloading Protomaps fonts and sprites..."
  wget -q "https://github.com/protomaps/basemaps-assets/archive/refs/heads/main.zip" -O /tmp/basemaps-assets.zip
  unzip -q /tmp/basemaps-assets.zip -d /tmp/
  mv /tmp/basemaps-assets-main/fonts map/fonts
  mv /tmp/basemaps-assets-main/sprites map/sprites
  rm -rf /tmp/basemaps-assets-main /tmp/basemaps-assets.zip
fi

rsync -avz --exclude "deploy.sh" --exclude ".git" --exclude ".env" \
  --include ".env.argon" \
  ./ "${REMOTE}:${REMOTE_DIR}/"

ssh "${REMOTE}" "cp ${REMOTE_DIR}/.env.argon ${REMOTE_DIR}/.env"

echo "Deployed to ${REMOTE}:${REMOTE_DIR}"

# Deploy Sentinel HA integration from the sentinel repo (non-fatal — warns on failure)
deploy_sentinel() {
  echo "Pulling latest Sentinel HA integration..."
  local tmp
  tmp=$(mktemp -d)
  git clone --depth=1 git@github.com:arudyk/sentinel.git "$tmp"

  ssh "${REMOTE}" "mkdir -p ${REMOTE_DIR}/data/homeassistant/custom_components ${REMOTE_DIR}/data/homeassistant/www"

  rsync -avz "$tmp/ha-integration/custom_components/sentinel/" \
    "${REMOTE}:${REMOTE_DIR}/data/homeassistant/custom_components/sentinel/"

  rsync -avz "$tmp/ha-integration/www/sentinel-card.js" \
    "${REMOTE}:${REMOTE_DIR}/data/homeassistant/www/"

  rm -rf "$tmp"

  echo "Sentinel integration deployed — restarting Home Assistant..."
  ssh "${REMOTE}" "cd ${REMOTE_DIR} && docker compose restart homeassistant"
  echo "Home Assistant restarted."
}

deploy_sentinel || echo "WARNING: Sentinel integration deploy failed — skipping."
