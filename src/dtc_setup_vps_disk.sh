#!/bin/sh

if [ $# -lt 3 ]; then 
	echo "Usage: $0 <xen id> <hdd size> <swap size>"
fi

# Things that often change

# Source the configuration in the config file!
. /etc/dtc-xen/dtc_create_vps.conf.sh

#NODE_NUM=6501
#DEBIAN_REPOS="http://65.apt-proxy.gplhost.com:9999/debian"
#NETMASK=255.255.255.0
#NETWORK=202.124.18.0
#BROADCAST=202.124.18.255
#GATEWAY=202.124.18.1

# Things that might change
LVMNAME=lvm1
VPSGLOBPATH=/xen
#KERNELNAME="2.6.11.12-xenU"
KERNELPATH="/boot/vmlinuz-${KERNELNAME}"
#DEBIAN_BINARCH=i386

# Things that most of then time don't change
VPSNUM=$1
VPSNAME=xen${VPSNUM}
VPSHOSTNAME=xen${NODE_NUM}${VPSNUM}
VPSHDD=$2
VPSMEM=$3

LVCREATE=/sbin/lvcreate
LVREMOVE=/sbin/lvremove
MKFS=/sbin/mkfs.ext3
MKDIR=/bin/mkdir
MKSWAP=/sbin/mkswap
MOUNT=/bin/mount

echo "Seleted ${VPSNAME}: ${VPSHDD}G HDD and ${VPSMEM}MB RAM";
echo "Creating disks..."

# Remove existing partitions if they existed
if [ -L /dev/${LVMNAME}/${VPSNAME} ] ; then
	$LVREMOVE -f /dev/${LVMNAME}/${VPSNAME}
fi
if [ -L /dev/${LVMNAME}/${VPSNAME}swap ] ; then
	$LVREMOVE -f /dev//${LVMNAME}/${VPSNAME}swap
fi

# (re)create the partitions
if [ ! -L /dev/${LVMNAME}/${VPSNAME} ] ; then
	$LVCREATE -L${VPSHDD}G -n${VPSNAME} ${LVMNAME}
	$MKDIR -p ${VPSGLOBPATH}/${VPSNUM}
fi
if [ ! -L /dev/${LVMNAME}/${VPSNAME}swap ] ; then
	$LVCREATE -L${VPSMEM} -n${VPSNAME}swap ${LVMNAME}
fi
if grep ${VPSNAME} /etc/fstab >/dev/null ; then
	echo "LV already exists in fstab"
else
	echo "/dev/mapper/${LVMNAME}-${VPSNAME}  ${VPSGLOBPATH}/${VPSNUM} ext3    defaults,noauto 0 0" >>/etc/fstab
fi
