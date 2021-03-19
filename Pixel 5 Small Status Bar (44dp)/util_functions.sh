#!/sbin/sh

##########################################################################################
# Environment
##########################################################################################

OUTFD=$2
ZIPFILE=$3

mount /data 2>/dev/null


# Preperation for flashable zips
setup_flashable

# Mount partitions
mount_partitions

# Detect version and architecture
api_level_arch_detect

# Setup busybox and binaries
$BOOTMODE && boot_actions || recovery_actions

##########
# Presets
##########

# Detect whether in boot mode
[ -z $BOOTMODE ] && BOOTMODE=false
$BOOTMODE || ps | grep zygote | grep -qv grep && BOOTMODE=true
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -qv grep && BOOTMODE=true

###################
# Helper Functions
###################

ui_print() {
  $BOOTMODE && echo "$1" || echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD

######################
# Environment Related
######################

setup_flashable() {
  # Preserve environment varibles
  OLD_PATH=$PATH
  ensure_bb
  $BOOTMODE && return
  if [ -z $OUTFD ] || readlink /proc/$$/fd/$OUTFD | grep -q /tmp; then
    # We will have to manually find out OUTFD
    for FD in `ls /proc/$$/fd`; do
      if readlink /proc/$$/fd/$FD | grep -q pipe; then
        if ps | grep -v grep | grep -q " 3 $FD "; then
          OUTFD=$FD
          break
        fi
      fi
    done
  fi
}

ensure_bb() {
  if [ -x $MAGISKTMP/busybox/busybox ]; then
    [ -z $BBDIR ] && BBDIR=$MAGISKTMP/busybox
  elif [ -x $TMPDIR/bin/busybox ]; then
    [ -z $BBDIR ] && BBDIR=$TMPDIR/bin
  else
    # Construct the PATH
    [ -z $BBDIR ] && BBDIR=$TMPDIR/bin
    mkdir -p $BBDIR
    ln -s $MAGISKBIN/busybox $BBDIR/busybox
    $MAGISKBIN/busybox --install -s $BBDIR
  fi
  echo $PATH | grep -q "^$BBDIR" || export PATH=$BBDIR:$PATH
}

recovery_actions() {
  # Make sure random don't get blocked
  mount -o bind /dev/urandom /dev/random
  # Unset library paths
  OLD_LD_LIB=$LD_LIBRARY_PATH
  OLD_LD_PRE=$LD_PRELOAD
  OLD_LD_CFG=$LD_CONFIG_FILE
  unset LD_LIBRARY_PATH
  unset LD_PRELOAD
  unset LD_CONFIG_FILE
  # Force our own busybox path to be in the front
  # and do not use anything in recovery's sbin
  export PATH=$BBDIR:/system/bin:/vendor/bin
}

recovery_cleanup() {
  export PATH=$OLD_PATH
  [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
  [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
  [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
  ui_print "- Unmounting partitions"
  umount -l /system_root 2>/dev/null
  umount -l /system 2>/dev/null
}

#######################
# Installation Related
#######################

find_block() {
  for BLOCK in "$@"; do
    DEVICE=`find /dev/block -type l -iname $BLOCK | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  # Fallback by parsing sysfs uevents
  for uevent in /sys/dev/block/*/uevent; do
    local DEVNAME=`grep_prop DEVNAME $uevent`
    local PARTNAME=`grep_prop PARTNAME $uevent`
    for BLOCK in "$@"; do
      if [ "`toupper $BLOCK`" = "`toupper $PARTNAME`" ]; then
        echo /dev/block/$DEVNAME
        return 0
      fi
    done
  done
  return 1
}

mount_part() {
  local PART=$1
  local POINT=/${PART}
  [ -L $POINT ] && rm -f $POINT
  mkdir $POINT 2>/dev/null
  is_mounted $POINT && return
  ui_print "- Mounting $PART"
  mount -o ro $POINT 2>/dev/null
  if ! is_mounted $POINT; then
    local BLOCK=`find_block $PART$SLOT`
    mount -o ro $BLOCK $POINT
  fi
  is_mounted $POINT || abort "! Cannot mount $POINT"
}

mount_partitions() {
  # Check A/B slot
  SLOT=`grep_cmdline androidboot.slot_suffix`
  if [ -z $SLOT ]; then
    SLOT=`grep_cmdline androidboot.slot`
    [ -z $SLOT ] || SLOT=_${SLOT}
  fi
  [ -z $SLOT ] || ui_print "- Current boot slot: $SLOT"

  mount_part system
  if [ -f /system/init.rc ]; then
    SYSTEM_ROOT=true
    [ -L /system_root ] && rm -f /system_root
    mkdir /system_root 2>/dev/null
    mount --move /system /system_root
    mount -o bind /system_root/system /system
  else
    grep -qE '/dev/root|/system_root' /proc/mounts && SYSTEM_ROOT=true || SYSTEM_ROOT=false
  fi
  [ -L /system/vendor ] && mount_part vendor
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
}
