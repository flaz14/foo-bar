#!/bin/bash

###   This stupid file contains some usefull Bash
###   settings and aliases (indended to be used   
###   only in command line).


### Settings for Bash history

# do not track duplicate commands
export HISTCONTROL=ignoredups

# use unlimited history in Bash
HISTSIZE='unlimited'
HISTFILESIZE='unlimited'



### Custom aliases

# reset terminal (clear all its content, so terminal 
# emulator will look like it just opened)
alias tclear='setterm -reset'

# long and human readable listing of a directory
alias ll='ls -l --all --human-readable --group-directories-first'

# convert from CP866 to UTF8 (input file should be specified
# by first argument, output will be put to stdout)
alias dos-to-linux='iconv --from-code=cp866 --to-code=utf8'

# pretty print XML file
alias cat-xml='xmllint --format "$1"'

# print web page by URL
alias cat-http='wget -q -O - "$1"'

# Lists all opened TCP and UDP ports.
function ls-tcpudp {
	netstat --all --numeric --program --tcp --udp --wide
}

# Prints PID of the process that uses TCP or UDP port 
# specified by first argument.
function find-pid-by-used-port {
	local inquired_port="$1"
	local netstat_output="$(ls-tcpudp 2>/dev/null)"
	echo -n "$netstat_output" | \
	while read line; do
		# ignore auxiliary information provided by 'netstat'
		local relevant_line="$(echo -n "$line" | grep '^[tu][cd][p]')"
		if [[ -z "$relevant_line" ]]; then 
			continue
		fi
		
		local candidate_port="$(echo -n "$relevant_line" | \
		                        awk '{print $4}' | \
		                        awk --field-separator : '{print $2}')"
		local candidate_pid="$(echo -n "$relevant_line" | \
		                       awk '{print $7}' | \
		                       awk --field-separator / '{print $1}')"
		
		# ignore ports when corresponding PID cannot be determined
		if [[ "$candidate_pid" == '-' || -z "$candidate_pid" ]]; then
			continue
		fi
		
		# match ports exactly
		if [[ "$candidate_port" != "$inquired_port" ]]; then 
			continue
		fi
		
		echo "$candidate_pid"
	done
}

