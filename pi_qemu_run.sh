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


qemu-system-arm -kernel $KERNEL -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio \
                -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" -hda $PI_DISK -hdb $SWAP

# Update - 
