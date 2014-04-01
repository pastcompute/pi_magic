#!/bin/bash
#
# pi post install script - adds some standard packages, and reduce amount of redownloading during
# testing by allowing caching of retrieved deb packages.
#
# Installs localepurge to remove some space.
#
# Assumes:
#
# - pi config program up to date
# - pi password set
# - boot to desktop set
# - ssh enabled
# - locale set - e.g. en_AU.UTF-8
# - timezone set
# - hostname set - e.g. pivm1
#
# Bootstrapping requires following qemu network config: basic NAT, with SSH port redirect
#

# Change these in your environment as desired
PI_USER=${PI_USER:-pi}
PI_PORT=${PI_PORT:-60022}
PI_SSH_HOST=${PI_SSH_HOST:-localhost}
PI_HOSTNAME=${PI_HOSTNAME:-pivm1}
OTHER_PACKAGES="tcpdump di git gitg gkrellm $PI_OTHER_PACKAGES"

SELF=$0

# Copy ourselves to the pi vm. Setup key so we can avoid excess passwordiness
function bootstrap() {
  ssh -p $PI_PORT ${PI_USER}@${PI_SSH_HOST} "install -d -m 700 ~/.ssh && grep -q '`cat ~/.ssh/id_rsa.pub`' ~/.ssh/authorized_keys || echo `cat ~/.ssh/id_rsa.pub` >> ~/.ssh/authorized_keys"
  scp -P $PI_PORT "$SELF" ${PI_USER}@${PI_SSH_HOST}:
  [ -n "$PRE_HOOK_SCRIPT" ] && . "$PRE_HOOK_SCRIPT"
  ssh -p $PI_PORT ${PI_USER}@${PI_SSH_HOST} sudo "$SELF" baseline
  ssh -p $PI_PORT ${PI_USER}@${PI_SSH_HOST} sudo "$SELF" finalise
  [ -n "$POST_HOOK_SCRIPT" ] && . "$POST_HOOK_SCRIPT"
}

# if no arguments specified, detect if we are a pi or not
# for now, assume that we wont be doing this form another PI or ARM VM
if [ $# -eq 0 ] ; then
  cat /proc/cpuinfo | grep "model name" | grep -q ": ARM" && echo "Must specify an argument running on the pi." && exit 1
  bootstrap
  exit 0
fi

# Actually setup our preferred package set
function baseline() {
  apt-get -q update
  apt-get install -qy debconf-utils
  cat > /tmp/debconf.seed <<EOF
localepurge	localepurge/nopurge	multiselect	en, en_AU.UTF-8
localepurge	localepurge/verbose	boolean	false
localepurge	localepurge/showfreedspace	boolean	true
localepurge	localepurge/quickndirtycalc	boolean	true
EOF
  DEBIAN_FRONTEND=noninteractive apt-get install -yq localepurge
  localepurge
  DEBIAN_FRONTEND=noninteractive apt-get install -yq  sysfsutils $OTHER_PACKAGES
  echo OK.
}

# Put /tmp etc. into tmps
# Ensure noop scheduler https://wiki.debian.org/SSDOptimization
# Reduce cache disk writes http://lonesysadmin.net/2013/12/22/better-linux-disk-caching-performance-vm-dirty_ratio/
# https://wiki.debian.org/DebianAcerOne#Reducing_Disk_Access_for_laptops_with_SSDs
# We trade-off against data loss because in normal operatoin wont be doing much writing
function finalise() {
  sed -e 's/^#[ \t]*RAMTMP=no/RAMTMP=yes/' -i /etc/default/tmpfs
  cat > /etc/sysctl.d/mypi.conf <<EOF
vm.dirty_background_ratio=20    # raspbian default is 10
vm.dirty_ratio=35               # raspbian default is 20
vm.dirty_expire_centisecs=6000  # raspbian default is 3000
EOF
  # note also, pi default in /etc/sysctl.conf is vm.swappiness=1
  #  what is sda in real pi? /dev/mmcblk0 - note, already noatime
  echo "block/sda/queue/scheduler = deadline" >> /etc/sysfs.conf 
  echo OK.
}

[ "$1" == "baseline" ] && baseline
[ "$1" == "finalise" ] && finalise


# Example for "$PRE_HOOK_SCRIPT" :
# We previously saved downloaded DEB packages, so we can avoid waiting yet again for them all to download
# The following command was run in  VM:
#     rsync -av /var/cache/apt/archives/ me@10.0.2.2:/scratch/rpi/apt-cache/
# So the PRE_HOOK_SCRIPT can copy all those to pivm1:/var/cache/apt/archives for us

