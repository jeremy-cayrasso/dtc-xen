#!/bin/sh

if [ $# -lt 1 ]; then 
	echo "Usage: $0 <xen id> [lvm/vbd]"
	exit
fi

# Things that often change

# Source the configuration in the config file!
. /etc/dtc-xen/dtc_create_vps.conf.sh

# Things that might change
# LVMNAME=lvm1
VPSGLOBPATH=${VPS_MOUNTPOINT}

# Things that most of then time don't change
VPSNUM=$1
VPSNAME=xen${VPSNUM}
VPSHOSTNAME=xen${NODE_NUM}${VPSNUM}
IMAGE_TYPE=$2

# redirect stdout and stderr to log files, so we can see what happened during install

echo "Redirecting standard output to $VPSGLOBPATH/$VPSNUM.stdout..."
echo "Redirecting standard error to $VPSGLOBPATH/$VPSNUM.stderr..."
if [ -e $VPSGLOBPATH/$VPSNUM.setuplvm.stdout ]; then
        mv $VPSGLOBPATH/$VPSNUM.setuplvm.stdout $VPSGLOBPATH/$VPSNUM.setuplvm.stdout.old
fi
if [ -e $VPSGLOBPATH/$VPSNUM.setuplvm.stderr ]; then
        mv $VPSGLOBPATH/$VPSNUM.setuplvm.stderr $VPSGLOBPATH/$VPSNUM.setuplvm.stderr.old
fi

exec 1>$VPSGLOBPATH/$VPSNUM.setuplvm.stdout
exec 2>$VPSGLOBPATH/$VPSNUM.setuplvm.stderr


if [ -z ""$IMAGE_TYPE ]; then
	IMAGE_TYPE=lvm
fi

LVCREATE=/sbin/lvcreate
LVREMOVE=/sbin/lvremove
MKFS=/sbin/mkfs.ext3
MKDIR=/bin/mkdir
MKSWAP=/sbin/mkswap

echo "Seleted ${VPSNAME}";
echo "Destroying disks..."

if [ ""$IMAGE_TYPE = "lvm" ]; then
	# Remove existing partitions if they existed
	if [ -L /dev/${LVMNAME}/${VPSNAME} ] ; then
		$LVREMOVE -f /dev/${LVMNAME}/${VPSNAME}
	fi
	if [ -L /dev/${LVMNAME}/${VPSNAME}swap ] ; then
		$LVREMOVE -f /dev/${LVMNAME}/${VPSNAME}swap
	fi
else
	if [ -e ${VPSGLOBPATH}/${VPSNAME}.img ]; then
		umount ${VPSGLOBPATH}/${VPSNAME}.img
		rm ${VPSGLOBPATH}/${VPSNAME}.img
	fi
	if [ -e ${VPSGLOBPATH}/${VPSNAME}.swap.img ]; then
		umount ${VPSGLOBPATH}/${VPSNAME}.swap.img
		rm ${VPSGLOBPATH}/${VPSNAME}.swap.img
	fi
fi

# Remove the auto start file
if [ -f /etc/xen/auto/${VPSNAME} ] ; then
	rm /etc/xen/auto/${VPSNAME}
fi
