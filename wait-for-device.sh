#!/bin/sh
# Generic wait-for-device helper for containers that depend on USB/external devices
# Usage: wait-for-device /path/to/device [max_retries] [retry_delay_seconds]

DEVICE="$1"
MAX_RETRIES="${2:-30}"
RETRY_DELAY="${3:-2}"

if [ -z "$DEVICE" ]; then
  echo "Usage: $0 <device_path> [max_retries] [retry_delay]"
  exit 1
fi

RETRY=0
while [ ! -e "$DEVICE" ] && [ ${RETRY} -lt ${MAX_RETRIES} ]; do
  if [ ${RETRY} -gt 0 ]; then
    echo "Waiting for $DEVICE... (attempt $((RETRY + 1))/${MAX_RETRIES})"
  else
    echo "Waiting for $DEVICE to be available..."
  fi
  sleep ${RETRY_DELAY}
  RETRY=$((RETRY + 1))
done

if [ ! -e "$DEVICE" ]; then
  echo "ERROR: $DEVICE not found after ${MAX_RETRIES} attempts"
  exit 1
fi

echo "Device $DEVICE is ready"
exit 0
