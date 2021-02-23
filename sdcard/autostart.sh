#!/bin/sh
ifconfig -a | grep eth0
RESULT=$?
if [ $RESULT -eq 0 ]; then
    ifconfig eth0 down
    ifconfig eth0 10.1.1.43 up
    ifconfig eth0 down
    ifconfig eth0 10.1.1.43 up
	ifconfig eth0 10.1.1.43 netmask 255.255.255.0
	piradio&
	rftool
fi
echo "Done!"
