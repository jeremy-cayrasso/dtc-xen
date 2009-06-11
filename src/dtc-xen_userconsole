#!/bin/sh

echo "Welcome to dtc-xen ssh console!"
sleep 1

if [ -n "$1" ]; then
	echo "Sorry, no shell commands allowed"
	exit 1
fi

sudo /usr/sbin/xm console $USER
