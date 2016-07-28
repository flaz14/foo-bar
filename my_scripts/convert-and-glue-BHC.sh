#!/bin/bash


# Чаще всего каждый релизенг журнала BHC - это zip-архив. Архив, в свою 
# очередь, содержит несколько текстовый файлов (собственно статьи, 
# которые называются bhc<номер релиза>-<номер статьи>.txt) 
# и разные дополнения (текст, картинки и пр., обычно расположены в 
# подкаталоге bhc-addons). 
# Этот скрипт извлекает из архива файлы статей (без дополнений), 
# склеивает воедино и сохраняет в одном файле (в кодировке UTF8).
#
# Работает начиная с BHC#6 (структура предыдущих релизов другая).
# Преобразование псевдографики из CP866 работает неидеально
# (то ли надо снабдить 'iconv' каким-нибудь дополнительным параметром,
# то ли заменять проблемные символы явно) но в целом получается 
# вполне читаемый текстовый файл.


# Проверяем переданные скрипту параметры
sourceZipFile="$1"
targetDir="$2"
if [ "${sourceZipFile}" = "" ]; then
	echo "Source zip archive is not specified. Abort." >&2
	exit 1
fi

if [ "${targetDir}" = "" ]; then
	echo "Target directory is not specified. Abort." >&2
	exit 1
fi
	
if [ ! -f "${sourceZipFile}" ]; then
	echo "Source zip file does not exist. Abort." >&2
	exit 2
fi

if [ ! -d "${targetDir}" ]; then
	echo "Destination directory does not exist. Abort." >&2
	exit 2
fi

# Извлекаем имя релизенга (это и есть имя файла архива, но без расширения '.zip')
regexForTakingReleaseNameFromFullPath='.*\/(.*)\.zip$'
[[ $sourceZipFile =~ $regexForTakingReleaseNameFromFullPath ]]
releaseName="${BASH_REMATCH[1]}"
if [ "${releaseName}" = "" ]; then 
	# обрабатываем ситуацию, когда путь к архиву указан из текущего каталога
	regexForTakingReleaseNameFromShortPath='^(.*)\.zip$'
	[[ $sourceZipFile =~ $regexForTakingReleaseNameFromShortPath ]]
	releaseName="${BASH_REMATCH[1]}"
fi

# Собираем серию команд (разархивирование, преобразование из CP866 в UTF8,
# склеивание нескольких текстовых файлов в один)
unzipCommandLine="unzip -p ${sourceZipFile} ${releaseName}\*.txt"
fullTargetFileName="${targetDir}/${releaseName}.txt"
mergeAndConvertCommandLine="iconv --from-code CP866 --to-code UTF8 > ${fullTargetFileName}"
jobCommandLine="${unzipCommandLine} | ${mergeAndConvertCommandLine}"

# Выполняем подготовленные команды
eval "${jobCommandLine}"

