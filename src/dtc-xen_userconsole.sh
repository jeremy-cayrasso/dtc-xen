#!/bin/sh

echo "None authorized connection are forbiden"
echo "Press enter to start the console!"
read toto
/usr/sbin/xm console $USER
