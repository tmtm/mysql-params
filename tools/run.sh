#!/bin/bash
set -e

start() {
    if [ -n "$pid" ]; then
        return
    fi
    /usr/local/mysql/bin/mysqld --no-defaults -umysql --skip-grant-tables &
    pid=$!
    while [ ! -e /tmp/mysql.sock ]; do
        sleep 1
    done
    bin/mysql --no-defaults -e "UPDATE mysql.user SET authentication_string='', password_expired='N' WHERE user='root' AND host='localhost'" || true
    kill $pid
    while [ -e /tmp/mysql.sock ]; do
        sleep 1
    done
    while :; do
        bin/mysqld --no-defaults -umysql &
        pid=$!
        while kill -0 $pid && [ ! -e /tmp/mysql.sock ]; do
            sleep 1
        done
        if kill -0 $pid; then
           break
        fi
    done
}

stop() {
    if [ -z "$pid" ]; then
        return
    fi
    kill $pid
    while ps -p $pid; do
        sleep 1
    done
    pid=
}

p_mysqld() {
    /usr/local/mysql/bin/mysqld --no-defaults -u mysql --help -v > $CURDIR/mysqld/data/$ver.txt || true
    sed -i -e "s/$(hostname)/hostname/g" $CURDIR/mysqld/data/$ver.txt
}

p_mysql() {
    /usr/local/mysql/bin/mysql --no-defaults --help -v > $CURDIR/mysql/data/$ver.txt || true
}

p_charset() {
    start
    bin/mysql --no-defaults -e 'SHOW CHARSET' > $CURDIR/charset/data/$ver.txt
}

p_collation() {
    start
    bin/mysql --no-defaults -e 'SHOW COLLATION' > $CURDIR/collation/data/$ver.txt
}

p_status() {
    start
    bin/mysql --no-defaults -e 'SHOW GLOBAL STATUS' | awk '{print $1}' > $CURDIR/status/data/$ver.txt
}

p_privilege() {
    start
    bin/mysql --no-defaults -e 'DESC mysql.user' > $CURDIR/privilege/data/$ver.txt
    bin/mysql --no-defaults -e 'DESC mysql.proxies_priv' >> $CURDIR/privilege/data/$ver.txt || true
    bin/mysql --no-defaults -e 'CREATE USER test; GRANT ALL ON *.* TO test WITH GRANT OPTION; SHOW GRANTS FOR test' >> $CURDIR/privilege/data/$ver.txt
}

p_func() {
    start
    : > $CURDIR/function/data/$ver.txt
    _func functions
}

_func() {
    tempfile=$(tempfile)
    bin/mysql --no-defaults -e "help $1" | grep '^  ' > $tempfile
    cat $tempfile | grep -iv 'functions\|operators' | sed -e 's/OPERATOR\|FUNCTION//' -e 's/^ *\| *$//' >> $CURDIR/function/data/$ver.txt || true
    cat $tempfile | grep -i 'functions\|operators' | while read l; do _func "$l"; done
    rm -f $tempfile
}

p_ischema() {
    bin/mysql --no-defaults -N information_schema -e "SELECT TABLE_NAME,COLUMN_NAME FROM COLUMNS WHERE TABLE_SCHEMA='information_schema'" > $CURDIR/ischema/data/$ver.txt
}

p_pschema() {
    bin/mysql --no-defaults -N information_schema -e "SELECT TABLE_NAME,COLUMN_NAME FROM COLUMNS WHERE TABLE_SCHEMA='performance_schema'" > $CURDIR/pschema/data/$ver.txt || true
}

p_error() {
    : > $CURDIR/error/data/$ver.txt
    grep '^#define ER_' include/mysqld_error.h | grep -Eo ' [0-9]+$' | while read e; do
        bin/perror $e 2> /dev/null | tr '\n' '\r' | sed -e 's/\r$/\n' -e 's/\r/\\n/' >> $CURDIR/error/data/$ver.txt 2> /dev/null || true
    done
}

all=1
while [ $# -gt 0 ]; do
    case "$1" in
        --mysqld | --mysql | --charset | --collation | --status | --privilege | --func | --ischema | --pschema | --error)
            eval "${1#--}=1"
            all=
            shift
            ;;
        *)
            break
            ;;
    esac
done

CURDIR=$(pwd)
mkdir -p $CURDIR/{mysqld,mysql,charset,collation,status,privilege,function,ischema,pschema,error}/data
for tar in "$@"; do
    echo "[[[[ $tar ]]]]"
    m=$(tar tf $tar | head -1 | cut -d/ -f1)
    ver=$(echo $m | egrep -o '[0-9]+\.[0-9]+\.[0-9]+')
    cd /tmp
    tar xf $tar
    rm -rf /usr/local/mysql
    mv /tmp/$m /usr/local/mysql
    cd /usr/local/mysql
    if [ -e scripts/mysql_install_db ]; then
        scripts/mysql_install_db --no-defaults
    else
        bin/mysqld --no-defaults --initialize
    fi
    chown -R mysql. .
    if [ -n "$all" -o -n "$mysqld" ];    then p_mysqld; fi
    if [ -n "$all" -o -n "$mysql" ];     then p_mysql; fi
    if [ -n "$all" -o -n "$charset" ];   then p_charset; fi
    if [ -n "$all" -o -n "$collation" ]; then p_collation; fi
    if [ -n "$all" -o -n "$status" ];    then p_status; fi
    if [ -n "$all" -o -n "$privilege" ]; then p_privilege; fi
    if [ -n "$all" -o -n "$func" ];      then p_func; fi
    if [ -n "$all" -o -n "$ischema" ];   then p_ischema; fi
    if [ -n "$all" -o -n "$pschema" ];   then p_pschema; fi
    if [ -n "$all" -o -n "$error" ];     then p_error; fi
    stop
done
