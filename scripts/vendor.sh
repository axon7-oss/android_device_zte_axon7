#!/system/bin/sh

TOYBOX="/system/bin/toybox"

# Get bootdevice.. don't assume /dev/block/sda
DISK=`${TOYBOX} readlink /dev/block/by-name/system | ${TOYBOX} sed -e's/[0-9]//g'`

# Check for /vendor existence
VENDOR=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep -c vendor`

if [ ${VENDOR} -ge 1 ] ; then
# Got it, we're done...
   exit 0
fi

# Missing... need to create it..
${TOYBOX} echo "/vendor missing"
#
# Get next partition...
LAST=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} tail -1 | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f2`
NEXT=`${TOYBOX} expr ${LAST} + 1`
NUMPARTS=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep 'holds up to' | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f6`

# Check if we need to expand the partition table
RESIZETABLE=""
if [ ${NEXT} -gt ${NUMPARTS} ] ; then
   RESIZETABLE=" --resize-table=${NEXT}"
fi

# Get /system partition #, start, ending, code
SYSPARTNUM=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f2`
SYSSTART=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f3`
SYSEND=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f4`
SYSCODE=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f7`

# Get sector size
SECSIZE=`/system/bin/sgdisk_axon7 --pretend --print ${DISK} | ${TOYBOX} grep 'sector size' | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f4`

## Resize part..
/system/bin/e2fsck /dev/block/by-name/system

# 512 = 512mb..
VENDORSIZE=`${TOYBOX} expr 512 \* 1024 \* 1024 / ${SECSIZE}`

NEWEND=`${TOYBOX} expr ${SYSEND} - ${VENDORSIZE}`
VENDORSTART=`${TOYBOX} expr ${NEWEND} + 1`

NEWSYSSIZE=`${TOYBOX} expr ${NEWEND} - ${SYSSTART} + 1`
MINSYSSIZE=`/system/bin/resize2fs_axon7 -P /dev/block/by-name/system 2>/dev/null | ${TOYBOX} grep minimum | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f7`

# Check if /system will shrink to small
if [ ${NEWSYSSIZE} -lt 0 ] ; then
   echo "ERROR: /system will be smaller than 0."
   exit 9
fi
if [ ${NEWSYSSIZE} -lt ${MINSYSSIZE} ] ; then
   echo "ERROR: /system will be smaller than the minimum allowed."
   exit 9
fi

# Resize /system, this will preserve the data and shrink it.
${TOYBOX} echo "*********Resize /system to ${NEWSYSSIZE} = ${NEWEND} - ${SYSSTART} + 1 (inclusize) = ${NEWSYSSIZE}"

### TO REALLY DO THIS, REMOVE THE echo ###
/system/bin/e2fsck -y -f /dev/block/by-name/system
### TO REALLY DO THIS, REMOVE THE echo ###
/system/bin/resize2fs_axon7 /dev/block/by-name/system ${NEWSYSSIZE}

# Only echo's for now... --pretend will NOT do it..
### TO REALLY DO THIS, REMOVE THE --pretend ###
/system/bin/sgdisk_axon7 ${RESIZETABLE} --delete=${SYSPARTNUM} --new=${SYSPARTNUM}:${SYSSTART}:${NEWEND} --change-name=${SYSPARTNUM}:system --new=${NEXT}:${VENDORSTART}:${SYSEND} --change-name=${NEXT}:vendor --print ${DISK}

echo /system/bin/sgdisk_axon7 --pretend ${RESIZETABLE} --delete=${SYSPARTNUM} --new=${SYSPARTNUM}:${SYSSTART}:${NEWEND} --change-name=${SYSPARTNUM}:system --new=${NEXT}:${VENDORSTART}:${SYSEND} --change-name=${NEXT}:vendor --print ${DISK}

## REALLY DO THIS ##
/system/bin/mke2fs -t ext4 ${DISK}${NEXT}
