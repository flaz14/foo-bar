#!/bin/bash

###############################################################################
# ОПИСАНИЕ
#
# Этот скрипт упаковывает перечисленные в разделе НАСТРОЙКИ каталоги в архив, 
# затем добавляет информацию, с использованием которой можно восстановить архив
# в случае его повреждения. 
# 
# Место сохранения архива нужно указать как первый аргумент командной строки.
# 
# В большинстве случаев, целостность архива важнее экономии места. 
# Но в случае с preallocated-дисками виртуальных машин экономия 
# благодаря сжатию получается существенной.

# НАСТРОЙКИ
#
# Список каталогов для архивирования. Этот список будет использован
# "как есть". Так что позаботьтесь об экранировании пробелов и т.п.
readonly IncludeFolders=(/home)
# Список каталогов, которые не будут архивироваться.
readonly ExcludeFolders=(/mnt /media /proc /sys /dev /windows)
# Завершаем выполнение скрипта как только встретим ошибку в любой строке.
set -e
###############################################################################

readonly ArchivePrefix='backup'
readonly ArchiveSuffix='.tar.gz'
readonly NewLineSymbol=$'\n'

# Специфичный для Bash трюк, который позволяет "прибить" скрипт из любой функции.
trap 'exit 1' TERM
export TOP_PID=$$
function abort() {
	echo "$1"
	kill -s TERM $TOP_PID
}

# Упрощает жизнь при обращении с путями вроде '/bin/../bin'.
function normalize_path() {
	local normalized="$(readlink --canonicalize "$1" 2>/dev/null)"
	echo "$normalized"
}

# Запрашивает у пользователя подтверждение на выполнение команды (да/нет), 
# предварительно напечатав ее на экране.
function ask_user_for_confirmation() {
	local answer='unknown'
	echo '---------------------------'
	echo 'Command line to be executed'
	echo '---------------------------'
	echo "$1"
	echo '---------------------------'
	until [[ "$answer" == 'y' || "$answer" == 'Y' || "$answer" == 'n' || "$answer" == 'N' ]]; do
		read -p 'Start backup now? [y/n] ' answer
		# если пользователь ответил 'n' или 'N', немедленно завершаем скрипт.
		case "$answer" in
			y|Y)	;;
			n|N)	abort 'Cancelled.' 
				;;
			*) echo 'Type y or n (or Ctrl+C to abort script)'
		esac 
	done
}

# Проверяет место сохранения архива (целевой каталог должен существовать и
# быть исключенным из архивирования во избежание проблем с рекурсией).
function check_in_exclude_folders() {
	local exclude_folders_normalized=()
	local folder=''
	for folder in "${ExcludeFolders[@]}"; do 
		local normalized="$(normalize_path "$folder")"
		exclude_folders_normalized+=("$normalized")
	done
	local is_found="$(find "${exclude_folders_normalized[@]}" \
			-wholename "$1" \
			-print -quit \
			2>/dev/null)"
	if [ -z "$is_found" ]; then
		abort "$(cat <<- EOF
			Specified destination directory is about to be archived.
			This can cause recursive archiving.
			EOF
		)"
	fi
}

function check_destination_directory() {
	echo 'Checking destination directory...'
	if [ -z "$1" ]; then
		abort 'Destinaion directory is not specified by the first parameter.'
	fi
	if [ ! -d "$1" ]; then
		abort 'Specified destination directory does not exist.'
	fi
	check_in_exclude_folders "$1"
	echo 'Destination directory is OK.'
}

# Собираем командную строку, которая собственно и выполняет архивирование.
# Зачем склеивать несколько команд в одну?
# Чтобы показать ее целиком пользователю (чтобы он убедился, что скрипт 
# выполнит именно то, что нужно).
function create_directory() {
	echo "mkdir '$1' && $NewLineSymbol cd '$1'"
}

function make_tar_gz() {
	local excludes_command_line=''
	local exclude_folder=''
	for exclude_folder in "${ExcludeFolders[@]}"; do 
		excludes_command_line="$excludes_command_line --exclude='$exclude_folder'"
	done
	local make_tar_gz="tar --create --file '$1' --gzip --ignore-failed-read "${IncludeFolders[@]}" $excludes_command_line"
	echo "$make_tar_gz"
}

function add_recovery_info() {
	echo "par2 create -r10 '$1'"
}

function compose_job_command_line() {
	local current_date="$(date +%d-%B-%Y)"
	local archive_directory="${1}/${ArchivePrefix}-${current_date}"
	local archive_file="${ArchivePrefix}-${current_date}${ArchiveSuffix}"
	echo " $(create_directory "$archive_directory") && $NewLineSymbol $(make_tar_gz "$archive_file") && $NewLineSymbol $(add_recovery_info "$archive_file")"
}

function main() {
	local destination_directory="$(normalize_path "$1")"
	check_destination_directory "$destination_directory"
	local job_command_line="$(compose_job_command_line "$destination_directory")"
	ask_user_for_confirmation "$job_command_line"
	echo 'Working...'
	sync
	eval "$job_command_line"
	sync
	echo 'Completed.'
}

###
main "$1"
###