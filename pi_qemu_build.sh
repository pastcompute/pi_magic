#!/bin/bash
#
# Given a fresh never-ran rpi raspbian image, fix it to work inside qemu
#
# It would be nice to do this completely as a non-root user
#
# Example:
#
# pi_qemu_build.sh -f /scratch/rpi/2013-02-09-wheezy-raspbian.img /scratch/rpi/hda1.qcow2
#
#

SUDO=sudo

KERNEL=image/kernel-qemu

# CWD for now ...
SNAPSHOT=snapshot.qcow2

FORCE=0
SKIP_COPY=0
while [ $# -gt 0 ] ; do
  if [ "$1" == "-f" ] ; then FORCE=1 ; shift ; continue; fi
  if [ "$1" == "-k" ] ; then SKIP_COPY=1 ; shift ; continue; fi

  # extra args are base image and output image
  if [ $# -gt 0 ] ; then ORIG_DISK="$1" ; DEST_DISK="$2" ; break ; fi
done

test -f "$ORIG_DISK" || { echo "Unable to read base image." ; exit 1 ; }
test -z "$DEST_DISK" && { echo "No destination specified." ; exit 1 ; }
test -e "$DEST_DISK" && [ $FORCE -eq 0 -a $SKIP_COPY -eq 0 ] && { echo "Destination exists." ; exit 1 ; }

#[ $SKIP_COPY -eq 0 ] && rsync -av "$ORIG_DISK" "$DEST_DISK"
# Create base image, which we will enlarge and tweak to allow raspbian to boot.
# Because the raspbian image only has a about 200MB free, and the pi menu SD expander doesnt work
# We can then use it as a backing image for qemu COW
[ $SKIP_COPY -eq 0 ] && qemu-img convert -p -O qcow2 "$ORIG_DISK" "$DEST_DISK" && qemu-img resize "$DEST_DISK" 4G

WORKING=/tmp/pi.$$
CHROOT=$WORKING/chroot
BYTES_SECTOR=512

QNDB=/dev/nbd0
LOOP=

function cleanup() {
  grep $CHROOT /proc/mounts && $SUDO umount $CHROOT
  $SUDO rm -rf $WORKING
  $SUDO losetup -d $LOOP
  $SUDO qemu-nbd -d $QNDB
}

trap cleanup 0

$SUDO modprobe nbd
$SUDO qemu-nbd -c $QNDB "$DEST_DISK" || exit 1

# Work out where sda2 starts in the image
# We assume it is the first (& only) ext4
$SUDO /sbin/parted -s $QNDB unit s print
START=`$SUDO /sbin/parted -s $QNDB unit s print | awk '/ext4/ {print $2}'`
OFFSET=$(( ${START%s} * $BYTES_SECTOR ))
LENGTH=`$SUDO /sbin/parted -s $QNDB unit s print | sed -n -e 's@Disk '$QNDB': \(.*\)s@\1@p'`

echo "Root Partition Start=$START Offset=$OFFSET Disk=$LENGTH"

# Extend sda2 out to nd of image
#$SUDO /sbin/parted -s $QNDB unit s move 2 $START $(( $LENGTH - 1 ))
# My (wheezy, 2.3) version of parted is stupid and wont even change the bounds of a partition 
$SUDO /sbin/parted -s $QNDB unit s rm 2 mkpart primary ext2 $START $(( $LENGTH - 1 ))
$SUDO /sbin/parted -s $QNDB unit s print

LOOP=`$SUDO losetup -o $OFFSET -f --show $QNDB`

echo "LOOP=$LOOP"
$SUDO /sbin/e2fsck -f $LOOP
$SUDO /sbin/resize2fs $LOOP
$SUDO /sbin/tune2fs -l $LOOP

mkdir -p $CHROOT

( set -x ; $SUDO mount -o loop,offset=$OFFSET $QNDB $CHROOT ) || exit 1

test -e $CHROOT/etc || { echo "Cannot find expected files..." && exit 1 ; }

echo Fixing preload

$SUDO sed -e '/^\/usr\/lib\/arm-linux-gnueabihf\/libcofi_rpi.so/ s/^/#/' -i $CHROOT/etc/ld.so.preload

echo Fixing mmc

cat > $WORKING/90-qemu.rules <<EOF 
KERNEL=="sda", SYMLINK+="mmcblk0"
KERNEL=="sda?", SYMLINK+="mmcblk0p%n"
KERNEL=="sda2", SYMLINK+="root"
EOF

$SUDO install $WORKING/90-qemu.rules -m 644 $CHROOT/etc/udev/rules.d/90-qemu.rules

cleanup

# Make a snapshot to use, using the base as a backing file.
qemu-img create -f qcow2 -o backing_file=$DEST_DISK $SNAPSHOT

# This is now redundant...
#qemu-system-arm -kernel $KERNEL -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio \
#                -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw init=/bin/bash" -hda "$DEST_DISK"

