#!/usr/bin/env bash
#
# Retry-launch an Oracle Cloud Always-Free Ampere A1 instance until capacity is
# available. Cycles through the availability domains you list and backs off
# between full rounds. Exits 0 on the first successful launch, non-zero on any
# error that is NOT an out-of-capacity error (so real problems surface instead
# of looping forever).
#
# Usage:
#   1. Install + configure the OCI CLI (see README.md).
#   2. cp launch.env.example launch.env  &&  fill in the OCIDs.
#   3. ./launch-retry.sh            # or:  ./launch-retry.sh /path/to/other.env
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/launch.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing config file: $ENV_FILE" >&2
  echo "Copy launch.env.example to launch.env and fill in your OCIDs." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# Required config.
: "${COMPARTMENT_OCID:?Set COMPARTMENT_OCID in $ENV_FILE}"
: "${SUBNET_OCID:?Set SUBNET_OCID in $ENV_FILE}"
: "${IMAGE_OCID:?Set IMAGE_OCID in $ENV_FILE}"
: "${SSH_PUBKEY_PATH:?Set SSH_PUBKEY_PATH in $ENV_FILE}"
: "${ADS:?Set ADS to a space-separated list of availability-domain names in $ENV_FILE}"

# Optional config with sensible defaults.
: "${DISPLAY_NAME:=angular-dotnet}"
: "${SHAPE:=VM.Standard.A1.Flex}"
: "${OCPUS:=4}"
: "${MEMORY_GB:=24}"
: "${BOOT_VOLUME_GB:=50}"
: "${SLEEP_SECONDS:=60}"

if [ ! -f "$SSH_PUBKEY_PATH" ]; then
  echo "SSH public key not found at: $SSH_PUBKEY_PATH" >&2
  exit 1
fi
SSH_PUBKEY="$(cat "$SSH_PUBKEY_PATH")"

read -r -a AD_ARR <<<"$ADS"

echo "Launching '$DISPLAY_NAME' ($SHAPE: ${OCPUS} OCPU / ${MEMORY_GB} GB)"
echo "Cycling ADs: ${AD_ARR[*]}  — retrying every ${SLEEP_SECONDS}s on capacity errors."
echo "Press Ctrl-C to stop."
echo

attempt=0
while true; do
  for AD in "${AD_ARR[@]}"; do
    attempt=$((attempt + 1))
    printf '[%s] attempt #%d — %s ... ' "$(date '+%H:%M:%S')" "$attempt" "$AD"

    if OUT=$(oci compute instance launch \
      --availability-domain "$AD" \
      --compartment-id "$COMPARTMENT_OCID" \
      --shape "$SHAPE" \
      --shape-config "{\"ocpus\": ${OCPUS}, \"memoryInGBs\": ${MEMORY_GB}}" \
      --subnet-id "$SUBNET_OCID" \
      --assign-public-ip true \
      --image-id "$IMAGE_OCID" \
      --boot-volume-size-in-gbs "$BOOT_VOLUME_GB" \
      --display-name "$DISPLAY_NAME" \
      --metadata "{\"ssh_authorized_keys\": \"${SSH_PUBKEY}\"}" \
      --wait-for-state RUNNING \
      2>&1); then
      echo "SUCCESS"
      echo
      echo "$OUT"
      INSTANCE_ID=$(echo "$OUT" | grep -oE 'ocid1\.instance\.[a-z0-9.-]+' | head -1 || true)
      if [ -n "$INSTANCE_ID" ]; then
        echo
        echo "Public IP:"
        oci compute instance list-vnics --instance-id "$INSTANCE_ID" \
          --query 'data[0]."public-ip"' --raw-output 2>/dev/null || true
      fi
      echo
      echo "✅ Instance is RUNNING. Copy the public IP above and report it back."
      exit 0
    fi

    if echo "$OUT" | grep -qiE 'out of (host )?capacity|outofcapacity'; then
      echo "no capacity"
    else
      echo "ERROR (non-capacity) — stopping:"
      echo "$OUT" >&2
      exit 1
    fi
  done
  echo "  …all ADs full; sleeping ${SLEEP_SECONDS}s"
  sleep "$SLEEP_SECONDS"
done
