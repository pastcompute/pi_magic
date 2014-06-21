#!/bin/bash
#
# Script to detect start of sda2 partition for use with losetup
#

IMAGE_FILE="$1"
BYTES_SECTOR=512

#/sbin/parted -s "$IMAGE_FILE" unit s print
START=`/sbin/parted -s "$IMAGE_FILE" unit s print | awk '/ext4/ {print $2}'`
PARTLEN=`/sbin/parted -s "$IMAGE_FILE" unit s print | awk '/ext4/ {print $4}'`
LENGTH=`/sbin/parted -s "$IMAGE_FILE" unit s print | sed -n -e 's@Disk .*: \(.*\)s@\1@p'`

OFFSET=$(( ${START%s} * $BYTES_SECTOR ))
PARTLEN=$(( ${PARTLEN%s} * $BYTES_SECTOR ))


echo "Root Partition Start=$START OffsetBytes=$OFFSET Disk=$LENGTH PartLenBytes=$PARTLEN"

echo "Commands to use:"
echo "losetup -o $OFFSET --sizelimit $PARTLEN -f --show '$(pwd)/"$(basename "$IMAGE_FILE")"'"

