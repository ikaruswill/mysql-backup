#!/bin/bash

DEBUG=${DEBUG}
DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES:-true}
BACKUP_RETENTION=${BACKUP_RETENTION:-7}
BACKUP_PATH=${BACKUP_PATH:-/backups}
BACKUP_MYSQL_DB=${BACKUP_MYSQL_DB:-true}
EXTRA_ARGS=$@

echo 'Starting mysql-backup'

if [[ ${DEBUG} != "" ]]; then
	set -x
fi

function rotate_dumps {
	local db=$1
	echo "$db: Rotating dumps"
	
	ls -t | grep $db | sed -e 1,${BACKUP_RETENTION}d | xargs -d '\n' -I {} sh -c 'echo "Deleting $1" && rm -r $1 >/dev/null 2>&1' sh {}
}

function dump_db {
	local db=$1
	echo "$db: Dumping database"

	mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" \
	--add-drop-database --single-transaction \
	${EXTRA_ARGS} --databases $db \
	| gzip > "$db-`date +%Y-%m-%d`".sql.gz
}

if [[ ${DB_USER} == "" ]]; then
	echo "Missing DB_USER env variable"
	exit 1
fi
if [[ ${DB_PASS} == "" ]]; then
	echo "Missing DB_PASS env variable"
	exit 1
fi
if [[ ${DB_HOST} == "" ]]; then
	echo "Missing DB_HOST env variable"
	exit 1
fi

cd $BACKUP_PATH

if [[ ${ALL_DATABASES} != "true" ]]; then
	if [[ ${DB_NAME} == "" ]]; then
		echo "Missing DB_NAME env variable"
		exit 1
	fi
	dump_db $DB_NAME
	rotate_dumps $DB_NAME
else
	databases=`mysql --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`
	for db in $databases; do
	    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]]; then
	        dump_db $db
			rotate_dumps $db
	    fi
	done
fi

if [[ ${BACKUP_MYSQL_DB} == "true" ]]; then
	dump_db 'mysql'
fi

echo 'Backup complete'
