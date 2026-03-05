#!/bin/sh

PORT=${PORT:-/dev/ttyUSB0}
BAUDRATE=${BAUDRATE:-115200}
REPEAT=${REPEAT:-60}
HA_URL=${HA_URL:-http://host.docker.internal:8123}

if [ -z "${HA_TOKEN}" ]; then
  echo "ERROR: HA_TOKEN environment variable is required"
  exit 1
fi

echo "Starting gmc300, using port ${PORT} at ${BAUDRATE} baud"

# Get device serial number from first reading
SERIAL=$(gmc320 "${PORT}" "${BAUDRATE}" | jq -r '.attributes.serial')
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
