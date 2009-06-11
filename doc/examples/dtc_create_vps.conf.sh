#!/bin/sh
# This the configuration file for dtc-xen setup scripts (called uppon VM reinstallation)

NODE_NUM=99999
NODE_DOMAIN_NAME=example.com
DEBIAN_REPOS="ftp://ftp.us.debian.org/debian"
NETMASK=255.255.255.0
NETWORK=192.168.0.0
BROADCAST=192.168.0.255
GATEWAY=192.168.0.1
LVMNAME=vg0
VPS_MOUNTPOINT=/var/lib/dtc-xen/mnt
DEBIAN_RELEASE=lenny

KERNELNAME=2.6.26-2-xen-amd64
INITRDNAME=initrd.img-2.6.26-2-xen-amd64
