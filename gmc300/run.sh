#!/bin/sh

PORT=${PORT:-/dev/ttyUSB0}
BAUDRATE=${BAUDRATE:-115200}
REPEAT=${REPEAT:-60}
HA_URL=${HA_URL:-http://host.docker.internal:8123}
MAX_RETRIES=${MAX_RETRIES:-30}
RETRY_DELAY=${RETRY_DELAY:-2}

if [ -z "${HA_TOKEN}" ]; then
  echo "ERROR: HA_TOKEN environment variable is required"
  exit 1
fi

echo "Starting gmc300, using port ${PORT} at ${BAUDRATE} baud"

# Retry logic for device initialization
RETRY=0
SERIAL=""
while [ -z "${SERIAL}" ] && [ ${RETRY} -lt ${MAX_RETRIES} ]; do
  if [ ${RETRY} -gt 0 ]; then
    echo "Waiting for device to be available... (attempt $((RETRY + 1))/${MAX_RETRIES})"
    sleep ${RETRY_DELAY}
  fi

  SERIAL=$(gmc320 "${PORT}" "${BAUDRATE}" 2>/dev/null | jq -r '.attributes.serial' 2>/dev/null)
  RETRY=$((RETRY + 1))
done

if [ -z "${SERIAL}" ]; then
  echo "ERROR: Failed to connect to device after ${MAX_RETRIES} attempts"
  exit 1
fi

echo "Device serial: ${SERIAL}"

while true; do
  DATA=$(gmc320 "${PORT}" "${BAUDRATE}")
  echo "Reading: ${DATA}"

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${HA_URL}/api/states/sensor.gmc3xx_${SERIAL}" \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${DATA}")

  echo "HA API status: ${STATUS}"
  sleep "${REPEAT}"
done
