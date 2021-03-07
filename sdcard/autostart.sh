#!/bin/sh
ifconfig -a | grep eth0
RESULT=$?
if [ $RESULT -eq 0 ]; then
	/etc/init.d/networking stop
	ifconfig eth0 down
	ifconfig eth0 hw ether 02:02:02:02:02:43
	ifconfig eth0 10.1.1.43 up
	ifconfig eth0 10.1.1.43 netmask 255.255.255.0
	/etc/init.d/networking start
	ping 10.1.1.255 -c 4

	piradio&
	rftool
fi
echo "Done!"
