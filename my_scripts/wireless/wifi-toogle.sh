#!/bin/bash

###
# This script helps to toogle WiFi on the fucking Acer Aspire-ES1-521 laptop (because inborn combination of Fn + F3 keys
# doesn't work properly in Linux).
#
# It's possible to use `rfkill` command here. But `rfkill` doesn't get on with Gnome Network Manager. You can find more 
# information about race conditions between `rfkill` and Network Manager in the thread:
# [How can I keep a wireless card's radio powered off by default?]
# (https://askubuntu.com/questions/24171/how-can-i-keep-a-wireless-cards-radio-powered-off-by-default)
#
# So we use only possibilities of Network Manager, e.g. its command line interface here and evewhere when deal with 
# WiFi.
###

# Below is the sample output (e.g. copied'n'pasted from a terminal emulator) of `nmcli -fields WIFI nm status` command:
#WIFI      
#disabled  

nm_status="$(nmcli -fields WIFI nm status)"

total_lines_in_status="$(echo "$nm_status" | wc --lines)"

if (( $total_lines_in_status != 2 )); then
	error_message=$"Cannot determine WiFi status due to unexpected output from \`nmcli -fields WIFI nm status\`:\n$nm_status"
	notify-send 'Ugly Tricks' "$error_message"
	exit 1
fi

table_heading="$(echo "$nm_status" | head --lines=1)"

table_content="$(echo "$nm_status" | tail --lines=1)"

# The output of `nmcli status` command is a table. Items in the table are arranged with aid of spaces. For robust 
# verifying of WiFi's status we need to eliminate extra spaces. `xargs` helps us to achieve this (as well as remove 
# whitespaces in the middle of the string; however, that doesn't matter in our script).
#
# You can find more information about this trick in the answer of @makevoid:
# [How to trim whitespace from a Bash variable?](https://stackoverflow.com/a/12973694/4672928)
wifi_status="$(echo "$table_content" | xargs)"

if [ "$wifi_status" == 'disabled' ]; then
	wifi-turn-on.sh
elif [ "$wifi_status" == 'enabled' ]; then
	wifi-turn-off.sh
else
	error_message=$"Cannot determine WiFi status. Expected 'enabled' or 'disabled' but '$wifi_status' received."
	notify-send 'Ugly Tricks' "$error_message"
fi
