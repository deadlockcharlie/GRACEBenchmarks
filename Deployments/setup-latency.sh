#!/bin/sh
# Usage: setup-latency.sh <self> <peer1> <latency1> <peer2> <latency2> ...

SELF=$1
shift

echo "[$SELF] Resetting existing latency configuration..."
tc qdisc del dev eth0 root 2>/dev/null || true

# Root prio qdisc with 10 bands
tc qdisc add dev eth0 root handle 1: prio bands 10

COUNT=1

while [ $# -gt 0 ]; do
  PEER=$1
  DELAY=$2
  shift 2

  PEER_IP=$(getent hosts "$PEER" | awk '{ print $1 }')

  echo "[$SELF] Setting up latency to $PEER ($PEER_IP) = ${DELAY}ms"

  # Attach a netem qdisc to this band
  tc qdisc add dev eth0 parent 1:$COUNT handle ${COUNT}0: netem delay "${DELAY}ms"

  # Filter traffic for this peer into the band
  tc filter add dev eth0 protocol ip parent 1:0 prio $COUNT u32 \
    match ip dst "$PEER_IP"/32 flowid 1:$COUNT

  COUNT=$((COUNT+1))
done

echo "[$SELF] ✅ Latency configuration applied."
