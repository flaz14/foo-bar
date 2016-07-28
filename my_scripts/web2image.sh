#!/bin/bash

### Этот велосипед сделан для того, чтобы получать 
# скриншот HTML-странички в высоком разрешении,
# чтобы затем скриншот можно было распечатать на большом
# листе бумаги. Firefox не совсем корректно печатает
# (например, если страница содержит фигуры, 
# составленные из нескольких div'ов со всякими хитрыми
# border-radius'ами и градиентами, то такая страничка
# иногда в браузере отображается нормально, но на 
# печать выводиться исковерканной). Результаты 
# онлайн-сервисов не лучше.
#
# Размер получаемого скриншота можно произвольно (зависит от
# настроек X.org) регулировать. Масштабирование в браузере - 
# тоже. Текущие настройки Firefox при этом не затрагиваются. 
#
# Масштабирование странички - это отдельная задача. 
# Так, в Firefox есть параметр layout.css.devPixelsPerPx. 
# Если в качестве значения указать, к примеру, "1.05", 
# то все элементы странички увеличатся в 1.05 раза. 
# Но даже при таком малом увеличении игнорируются размеры 
# окна (если страница содержит таблицу,  ширина которой 
# задается как "width: 100%", то такая таблица
# просто будет обрезана справа, в то время как при 
# "правильном" масштабировании таблица будет всегда 
# (кроме очень большого увеличения) укладываться в ширину окна.
# Так что будем имитировать изменение масштаба в браузере 
# (как будто пользователь нажимает Ctrl +).                        #
                                                                 ###


### Настройки (править их не стоит).
declare -r profile_name="xvfb_jhnrfhbfbgi" # чтобы не имя совпадало с уже существующими
declare -r profile_regex="(.*)\.xvfb"
declare -r settings_file_regex=".*\.${profile_name}/prefs.js"
declare -r screen_size_regex="([[:digit:]]+)x([[:digit:]]+)"
declare -r zoom_regex="([[:digit:]]+)%"
declare -r firefox_home_directory=~/.mozilla/firefox    
declare -r display=5
declare -r hold_up_seconds=10 # предполагается, что за это количество секунд 
                              # в фоне запуститься и будет готова к работе программа 
                              # (Firefox или Xvfb)
declare -r zoom_delay=5 # предполагается, что за это время Firefox успеет 
			# отмасштабировать страничку
declare -r margin_top=71 # столько пикселей занимает адресная строка Firefox
declare -r margin_bottom=30 # столько пикселей занимает приглашение "Choose What I Share"
declare -r min_width=640
declare -r max_width=10000
declare -r min_height=480
declare -r max_height=10000
declare -r min_zoom=100
declare -r max_zoom=5000


# размеры виртуального экрана по умолчанию
# (соответствуют формату A1 при разрешении 300 DPI)
declare -r default_width=7017
declare -r default_height=9933
# масштаб по умолчанию, в %
declare -r default_zoom=100                                                             #
                                                                                      ###


### Проверяет статус процесса (запущенного из этого же скрипта).
wait_for() {
	sleep "$hold_up_seconds"
	local process_status=$(jobs -l | grep "$1" | awk '{ print $3; }' )
	case "$process_status" in
		'Running')	return 0;;
		* ) 		return 1;;
	esac                                                              
}                                                                         #
                                                                        ###


### Получает PID процесса (опять-таки, в рамках скрипта).
get_pid() {
	echo $(jobs -l | grep "$1" | awk '{ print $2; }' )   
}                                                          #
                                                         ###


### Справка об использовании скрипта.
print_usage_info() {
	local script_name=$(basename "$0")
	echo "Usage: $script_name URL OUTPUT_IMAGE WIDTHxHEIGHT ZOOM%"
	echo "       where:"
	echo "              URL  is a pointer to desired HTML page. It can be either HTTP-link to page or name of HTML-file on local machine. Mandatory."
	echo 
	echo "              OUTPUT_IMAGE  is name of file for resulting image. If it has extension (like .bmp or .jpeg) then resulting image will be stored"
	echo "                            in corresponding format. Note that if specified file already exists it will be overriden by script. Mandatory."
	echo 
	echo "              WIDTH and HEIGHT  are numbers."
	echo "                                WIDTH should be greater than $(($min_width -1)) and less than $(($max_width + 1))."
	echo "                                HEIGHT should be greater than $(($min_height - 1)) and less than $(($max_height + 1))."
	echo "                                Optional. Default is ${default_width}x${default_height}."
	echo 
	echo "              ZOOM  should be greater than $(($min_zoom -1)) and less than $(($max_zoom + 1)). Optional. Default is ${default_zoom}."
	echo
}  

### Печатает переданную первым параметром 
# строку и принудительно завершает скрипт.
abort() {
	print_usage_info
	echo -n "ERROR"
	[[ -n $1 ]] && echo -n ": $1"
	echo
	echo "Killing this script, pid=$BASHPID ..."
	kill -KILL $BASHPID
}                                                      #
                                                     ###


### Обрабатывает параметры, переданные скрипту.
# В случае ошибки показывает краткую справку.
parse_user_input() {
	url="$1"
	[[ -z "$url" ]] && abort "Input URL is not specified."
	output_image="$2"
	[[ -z "$output_image" ]] && abort "Output file name is not specified."

	# пытаемся определить размеры виртуального экрана	
	local screen_size=""	
	[[ $3 =~ $screen_size_regex ]] && screen_size="$3"
	[[ $4 =~ $screen_size_regex ]] && screen_size="$4"
	if [[ -n "$screen_size" ]]; then
		[[ $screen_size =~ $screen_size_regex ]] && \
		width=${BASH_REMATCH[1]} && \
		height=${BASH_REMATCH[2]} && \
		(( $width < $min_width || $width > $max_width )) && abort "Invalid width is specified."
		(( $height < $min_height || $height > $max_height )) && abort "Invalid height is specified."
		height=$(($height + $margin_top + $margin_bottom))
	else
		width=$default_width
		height=$(($default_height + $margin_top + $margin_bottom))
	fi

	# пытаемся определить масштаб
	local zoom_percent=""
	[[ $3 =~ $zoom_regex ]] && zoom_percent="$3"
	[[ $4 =~ $zoom_regex ]] && zoom_percent="$4"
	if [[ -n "$zoom_percent" ]]; then
		[[ $zoom_percent =~ $zoom_regex ]] && \
		zoom=$((${BASH_REMATCH[1]})) && \
		(( $zoom < $min_zoom || $zoom > $max_zoom )) && abort "Invalid zoom is specified."
	else
		zoom=$default_zoom
	fi
	echo "Parameters: URL=$url OUTPUT_IMAGE=$output_image WIDTH=$width HEIGHT=$height ZOOM=$zoom"
}


### Функции для работы с виртуальным экраном.
run_virtual_screen () {
	echo "Starting new virtual screen at display $display ..." 
	Xvfb :"$display" -screen 0 "$width"x"$height"x24 &
	wait_for 'Xvfb' && \
	virtual_screen_pid=$(get_pid 'Xvfb') && \
	echo "Virtual screen started, pid=$virtual_screen_pid"
}

stop_virtual_screen () {
	echo "Stopping virtual screen with pid=$virtual_screen_pid ..."
	kill -KILL "$virtual_screen_pid" && \
	echo "Virtual screen stopped."
}                                                                       #
                                                                      ###


### Функции для работы с Firefox.
start_firefox () {
	echo "Starting Firefox with profile '$profile_name' ..."
	firefox -new-instance -width "$width" -height "$height" -P "$profile_name" "$1" &
	wait_for 'firefox' && \
	firefox_pid=$(get_pid 'firefox') && \
	# имитируем нажатие Ctrl +, чтобы Firefox применил масштабирование
	firefox_window_id=$(xdotool search --name "Mozilla Firefox")
	[[ -n $firefox_window_id ]] || abort "Cannot find Firefox window."	
	echo "Found Firefox window, id=$firefox_window_id"
	xvkbd -window $firefox_window_id -text '\C+'
	# ждем некоторое время, пока браузер применяет масштабирование
	sleep $zoom_delay
	echo "Firefox started, pid=$firefox_pid"
}

stop_firefox () {
	echo "Stopping Firefox with pid=$firefox_pid ..."
	kill -KILL $firefox_pid && \
	echo "Firefox stopped."
}

create_temporary_profile () {
	echo "Creating temporary profile '$profile_name' ..."
	firefox -CreateProfile "$profile_name" -no-remote && \
	echo "Temporary profile created."
}

delete_temporary_profile () {
	echo "Deleting temporary profile '$profile_name' ..."
	local profile_directory=$(ls "$firefox_home_directory" | grep ".$profile_name") && \
	[[ $profile_directory =~ $profile_regex ]] && \
	local profile_directory_uid="${BASH_REMATCH[1]}" && \
	# рекурсивное удаление каталога не приведет к разрушительным последствиям, 
	# поскольку путь к нему собирается по-частям
	rm -rf -- "$firefox_home_directory/$profile_directory_uid.$profile_name" && \
	echo "Temporary profile deleted."
}                                                                                           
                                                                                           
tune_temporary_profile () {
	echo "Tuning temporary profile '$profile_name' ..."
	local settings_file=$(find "$firefox_home_directory" -regex "$settings_file_regex") && \
	echo "Editing settings file '$settings_file' ..."  
	# дополнительные настройки (чтобы Firefox не пытался восстановить вкладки 
	# после принудительного завершения)
	echo "user_pref(\"toolkit.max_resumed_crashes\", -1);" >> "$settings_file" && \
	echo "user_pref(\"browser.sessionstore.resume_from_crash\", false);" >> "$settings_file" && \
	echo "user_pref(\"browser.sessionstore.resume_from_crash\", false);" >> "$settings_file" && \
	# настраиваем масштаб (задаем два возможных масштаба, Firefox'у будет некуда 
	# деться, при нажатии Ctrl + он применит максимальный масштаб)
	local zoom_decimal=$(bc -l <<< "scale=2; $zoom / 100")
	local min_zoom_decimal=$(bc -l <<< "scale=2; $min_zoom / 100")
	echo "user_pref(\"toolkit.zoomManager.zoomValues\", \"$min_zoom_decimal,$zoom_decimal\");" >> "$settings_file" && \
	echo "user_pref(\"zoom.maxPercent\", $zoom);" >> "$settings_file" && \
 	echo "user_pref(\"zoom.minPercent\", $min_zoom);" >> "$settings_file" && \
	echo "Settings applied."
}                                                                                                                           #
                                                                                                                          ###


### Делает скриншот (адресная строка обрезается, границы окна - тоже).
take_screenshot () {
	actual_height=$(($height - $margin_bottom - $margin_top))	
	import -window root -crop "$width"x"$actual_height"+0+"$margin_top" "$1"
}                                                                               #
                                                                              ###


### Cкрипт ###
parse_user_input $@
# удаляем профиль (на тот случай, если скрипт был 
# аварийно завершен во время придыдущего запуска)
delete_temporary_profile
export DISPLAY=:"$display"
run_virtual_screen && \
create_temporary_profile && \
start_firefox && \
stop_firefox && \
tune_temporary_profile && \
start_firefox "$url" && \
take_screenshot "$output_image"
# независимо от того, успешно выполнились предыдущие команды
# или нет, завершаем запущенные программы и удалаем 
# ненужные файлы
stop_firefox
delete_temporary_profile
stop_virtual_screen

