#!/bin/bash
#
#
# ./pi_qemu_run.sh snapshot.qcow2
#
# Use qemu-img info snapshot.qcow2 to check it has correct backing store
#
KERNEL=image/kernel-qemu

SWAP=/scratch/rpi/swap1.img

PI_DISK="$1"

test -f "$PI_DISK" || { echo "Unable to detect image." ; exit 1 ; }

qemu-img create $SWAP 1024M

# qemu model versatilepb: ARM Versatile Platform/Application Baseboard System emulation
# defaults network eth0 onto basic qemu NAT, 10.0.2.15, can access host on 10.0.2.2

# TODO: prevent CTRL+C in serial terminal!

# Map ssh on (host) localhost:60022 --> (guest) 22
NET_SETUP="-net nic -net user,hostfwd=tcp::60022-:22"

qemu-system-arm -kernel $KERNEL -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio \
                -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw $APPEND_EXTRA" \
                ${NET_SETUP} -hda $PI_DISK -hdb $SWAP

# Update - 
