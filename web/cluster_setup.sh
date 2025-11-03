#!/bin/sh
# /etc/local.d/cluster.start - bootstraps PXE-booted Alpine Pi into swarm mode

CONTROLLER_IP="10.0.0.1"
SWARM_TOKEN="SWMTKN-1-1234"
SWARM_MANAGER_IP="$CONTROLLER_IP:2377"

### 1. Mount local storage for Docker data
### If the Pi has an SD card, use it for Docker storage
### Otherwise Docker will use tmpfs (RAM), which is not ideal but works for testing
if [ -b /dev/mmcblk0p1 ]; then
    echo "Mounting /dev/mmcblk0p1"
    mkdir -p /mnt/sdcard/docker
    mountpoint -q /mnt/sdcard || mount -o rw /dev/mmcblk0p1 /mnt/sdcard
else
    echo "Warning: no /dev/mmcblk0p1 found, Docker will use tmpfs"
fi

### 2. Set hostname from DNS PTR
### Uncomment this if you can get a valid PTR record eg from a local DNS server
# IP=$(ip -4 addr show dev eth0 | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
# if [ -n "$IP" ]; then
#     HOST=$(nslookup "$IP" 2>/dev/null \
#         | awk '/name =/ {print $4}' \
#         | sed 's/\.$//' \
#         | cut -d. -f1)
#     if [ -n "$HOST" ]; then
#         echo "Setting hostname to $HOST"
#         setup-hostname "$HOST"
#         hostname "$HOST"   # apply immediately without reboot
#     else
#         echo "No PTR record for $IP, keeping current hostname"
#     fi
# fi


### 3. Mount swarm NFS share
echo "Mounting swarm NFS share..."
mkdir -p /mnt/swarm
mountpoint -q /mnt/swarm || mount -t nfs -o vers=4.1,proto=tcp,rw,noatime,hard,timeo=600 $CONTROLLER_IP:/swarm /mnt/swarm

### 5. Enable/start Docker
apk add docker
sleep 3
/etc/init.d/cgroups start
sleep 2
/etc/init.d/docker start

### 6. Join Docker Swarm if not already a member
# Wait for Docker to be responsive (max ~20s)
for i in $(seq 1 20); do
    docker info >/dev/null 2>&1 && break
    sleep 1
done

if ! docker info >/dev/null 2>&1; then
    echo "Docker not responding; cannot join swarm."
    exit 0
fi

STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$STATE" = "active" ]; then
    echo "Already part of a swarm (state: $STATE); skipping join."
else
    echo "Attempting to join swarm at $SWARM_MANAGER_IP (state: ${STATE:-unknown})..."
    # Try to join; ignore the 'already part of a swarm' error
    if docker swarm join --token "$SWARM_TOKEN" "$SWARM_MANAGER_IP" 2> /tmp/swarm_join.err; then
        echo "Swarm join successful."
    else
        if grep -qi "This node is already part of a swarm" /tmp/swarm_join.err; then
            echo "Node already part of a swarm; continuing."
        else
            echo "Swarm join failed:"
            cat /tmp/swarm_join.err
        fi
    fi
fi