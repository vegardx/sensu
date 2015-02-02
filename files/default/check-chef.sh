#!/bin/sh
# Nagios check to verify chef-client based on log
# Copyright (C) 2011 Kristian Lyngstol <kristian@bohemians.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

if [ ! -r /var/log/chef/client.log ]; then
    echo "CRITICAL - no /var/log/chef/client.log readable"
    exit 3
fi
tail -n 20 /var/log/chef/client.log | grep -q ERROR
FOO=$?
if [ "$FOO" -eq "0" ]; then
    LASTLINE=$(grep ERROR /var/log/chef/client.log | tail -n2)
    LINE1=$(tail -n 250 /var/log/chef/client.log | grep ERROR | wc -l)
    if [ $LINE1 -gt 5 ]; then
        echo "CRITICAL - Chef failed (last 20 log lines). ${LINE1} failures over last 250 lines. Last: ${LASTLINE}"
        exit 2
    else
        echo "WARNING - Chef failed (last 20 log lines). ${LINE1} failures over last 250 lines. Last: ${LASTLINE}"
        exit 1
    fi
fi
MODTIME=$(stat /var/log/chef/client.log -c "%Y")
NOW=$(date +%s)
DIFF=$(( ${NOW} - ${MODTIME} ))
if [ $DIFF -gt 3600 ]; then
    echo "CRITICAL - chef log was modified more than 3600 seconds ago: ${DIFF}"
    exit 2
fi

LASTLINE=$(tail -n1 /var/log/chef/client.log)
echo "OK - chef-client. ${LASTLINE}"
exit 0
