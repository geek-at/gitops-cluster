#!/bin/sh

set -e

WEBSERVER_IP="10.0.0.1"
ALPINE_VERSION="v3.22"
TFTPDIR=$(dirname "$0")

wget https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/releases/aarch64/netboot/initramfs-rpi -P "$TFTPDIR"
wget https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/releases/aarch64/netboot/modloop-rpi -P "$TFTPDIR"
wget https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/releases/aarch64/netboot/vmlinuz-rpi -P "$TFTPDIR"

git clone --depth 1 https://github.com/raspberrypi/firmware.git /tmp/rpifirmware
cp /tmp/rpifirmware/boot/bcm2711* "$TFTPDIR"
cp /tmp/rpifirmware/boot/fixup4.dat "$TFTPDIR"
rm -rf /tmp/rpifirmware

cat <<EOF > "$TFTPDIR/cmdline.txt"
console=tty modules=loop,squashfs ip=dhcp modloop=https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/releases/aarch64/netboot/modloop-rpi alpine_repo=https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/main,https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VERSION/community apkovl=http://$WEBSERVER_IP/alpine.apkovl.tar.gz
EOF
    
cat <<EOF > "$TFTPDIR/config.txt"
kernel=vmlinuz-rpi
initramfs initramfs-rpi
arm_64bit=1
gpu_mem=0
EOF

