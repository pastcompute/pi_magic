#!/bin/bash
#
# It would be nice to do this completely as a non-root user
#

SUDO=sudo

DISK=hda.img
CHROOT=/tmp/pi.$$
BYTES_SECTOR=512

if false ; then

# Work out where sda2 starts in the image
# We assume it is the first (& only) ext4
OFFSET=`/sbin/parted -s $DISK unit s print | awk '/ext4/ {print $2}'`
OFFSET=$(( ${OFFSET%s} * $BYTES_SECTOR ))

mkdir -p $CHROOT

( set -x ; mount -o loop,offset=$OFFSET $DISK $CHROOT )

function cleanup() {
  umount $CHROOT
  rmdir $CHROOT
}

trap cleanup 0

test -e $CHROOT/etc || exit 1

sed -e '/\/usr\/lib\/arm-linux-gnueabihf\/libcofi_rpi.so/ s/^/#/' -i $CHROOT/etc/ld.so.preload

cat > $CHROOT/etc/udev/rules.d/90-qemu.rules <<EOF 
KERNEL=="sda", SYMLINK+="mmcblk0"
KERNEL=="sda?", SYMLINK+="mmcblk0p%n"
KERNEL=="sda2", SYMLINK+="root"
EOF

chmod 644 $CHROOT/etc/udev/rules.d/90-qemu.rules

#qemu-system-arm -kernel kernel-qemu -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw init=/bin/bash" -hda $DISK

fi 
qemu-system-arm -kernel kernel-qemu -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" -hda $DISK

