#!/bin/bash


overall_wifi_status=`rfkill list wifi`

total_lines_in_status=`echo "$overall_wifi_status" | wc --lines`

if (( $total_lines_in_status != 3 )); then
	error_message=$"Cannot determine WiFi status due to unexpected output from \`rfkill\`:\n$overall_wifi_status"
	notify-send 'Ugly Tricks' "$error_message"
fi

soft_blocked_line=`echo "$overall_wifi_status" | grep 'Soft blocked:'`

total_lines_in_soft_blocked_line=`echo "$soft_blocked_line" | wc --lines`

if (( $total_lines_in_soft_blocked_line !=1 )); then
	error_message=$"Soft blocked status is absent from \`rfkill\`:\n$overall_wifi_status"
	notify-send 'Ugly Tricks' "$error_message"
fi


wifi_status_regexp='Soft blocked: (yes|no)'
soft_blocked_line =~ $wifi_status_regexp
