#!/bin/bash
#
# oathverify for freeradius3
# written by Flavio Camacho, Brazil, 2024
# (c) 2024 by Flavio Camacho <flaviocamacho95@gmail.com>
#
# Version 1.0
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# arguments:  $1 $2 $3 $4 $5
# $1 - username
# $2 - one-time-password that is to be checked
# $3 - init-secred from token (to init token: #**#)
# $4 - user PIN
# $5 - time difference between token and server in 10s of seconds (360 = 1 hour)
#
# oath program is used to check the one-time-password
#
# oathverify.sh version 1.00, Dec. 2024
#
# program based on optverify.sh by Matthias Straub, Heilbronn, Germany, 2003

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

alias log="echo "

# ensure aliases are expanded by BASH_REMATCH
shopt -s expand_aliases

if [ ! $# -eq 5 ] ; then
	echo "USAGE: oauthverify.sh Username, OTP, Init-Secret, PIN, Offset"
	exit 14
fi

mkdir /var/log/oathverify 2>/dev/null
mkdir /var/log/oathverify/cache 2>/dev/null
mkdir /var/log/oathverify/users 2>/dev/null
chmod og-rxw /var/log/oathverify 2>/dev/null || { echo "FAIL! Need write-access to /var/log/oauth";log "FreeRADIUS: OAuth - need write-access to /var/log/oauth" >> /var/log/system.log; exit 17; }
chmod og-rxw /var/log/oathverify/cache
chmod og-rxw /var/log/oathverify/users

USERNAME=$(echo -n "$1" | sed 's/[^0-9a-zA-Z._-]/X/g' )
PASSWD=$(echo -n "$2" | sed 's/[^0-9a-f]/0/g' )
SECRET=$(echo -n "$3" | sed 's/[^0-9a-f]/0/g' )
PIN=$(echo -n "$4" | sed 's/[^0-9]/0/g' )
OFFSET=$(echo -n "$5" | sed 's/[^0-9-]/0/g' )

EPOCHTIME=$(date +"%Y-%m-%d %H:%M:%S" -u )

# delete old otp
find /var/log/oathverify/cache -type f -cmin +5 | xargs rm 2>/dev/null

if [ -e "/var/log/oathverify/cache/$PASSWD" ]; then
	echo "FAIL"
	log "FreeRADIUS: Authentication $USERNAME failed! OAuth $PASSWD is already used!" >> /var/log/oathverify/system.log 
	exit 15
fi

# delete user locked mote then 10min
find /var/log/oathverify/users -type f -cmin +10 | xargs rm 2>/dev/null

# account locked?
if [ "$(cat /var/log/oathverify/users/$USERNAME 2>/dev/null)" == "10" ]; then
	echo "FAIL"
	log "FreeRADIUS: Authentication $USERNAME failed! Too many wrong password attempts. User is locked! To unlock delete /var/log/oauth/users/$USERNAME or wait 10 minutes" >> /var/log/oathverify/system.log 
	exit 13
fi

# check PIN
if [[ $PASSWD =~ (.*)([0-9]{6})$ ]]; then
    CHECKPIN="${BASH_REMATCH[1]}"
    CHECKOTP="${BASH_REMATCH[2]}"
	if [ ! $PIN = $CHECKPIN ]; then
		echo "FAIL"
		NUMFAILS=$(cat "/var/log/oathverify/users/$USERNAME" 2>/dev/null)
		if [ "$NUMFAILS" = "" ]; then
			NUMFAILS=0
		fi
		NUMFAILS=$(expr $NUMFAILS + 1)
		echo $NUMFAILS > "/var/log/oathverify/users/$USERNAME"
		NUMFAILSLEFT=$(expr 10 - $NUMFAILS)
		log "FreeRADIUS: Authentication $USERNAME failed! PIN incorrect. $NUMFAILSLEFT attempts left. " >> /var/log/oathverify/system.log 
		exit 11
	fi
fi

# check OTP
I=0
EPOCHTIME=$(date +"%Y-%m-%d %H:%M:%S UTC" -u --date="$EPOCHTIME + 2 seconds" )
EPOCHTIME=$(date +"%Y-%m-%d %H:%M:%S UTC" -u --date="$EPOCHTIME - $OFFSET seconds" )
while [ $I -lt 4 ] ; do # `2 * 10` seconds before and after
	OTP=$(oathtool -b -N "$EPOCHTIME" --totp "$SECRET" )
	if [ "$OTP" = "$CHECKOTP" ] ; then
		touch /var/log/oathverify/cache/$OTP || { echo "FAIL! Need write-access to /var/log/oauth";log "FreeRADIUS: OAuth - need write-access to /var/log/oathverify/cache" >> /var/log/oathverify/system.log ; exit 17; }
		echo "ACCEPT"
		log "FreeRADIUS: Authentication success! OAuth $PASSWD for user $USERNAME is correct!" >> /var/log/oathverify/system.log 
		rm "/var/log/oathverify/users/$USERNAME" 2>/dev/null
		exit 0
	fi
	I=$(expr $I + 1)
	EPOCHTIME=$(date +"%Y-%m-%d %H:%M:%S UTC" -u --date="$EPOCHTIME + 1 seconds" )
done

# OTP fail
echo "FAIL"
NUMFAILS=$(cat "/var/log/oathverify/users/$USERNAME" 2>/dev/null)
if [ "$NUMFAILS" = "" ]; then
	NUMFAILS=0
fi
NUMFAILS=$(expr $NUMFAILS + 1)
echo $NUMFAILS > "/var/log/oathverify/users/$USERNAME"
NUMFAILSLEFT=$(expr 10 - $NUMFAILS)
log "FreeRADIUS: Authentication $USERNAME failed! OTP incorrect. $NUMFAILSLEFT attempts left. " >> /var/log/oathverify/system.log 
exit 11