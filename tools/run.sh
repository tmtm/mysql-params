#!/bin/bash
set -e

start() {
    if [ -n "$pid" ]; then
        return
    fi
    /usr/local/mysql/bin/mysqld --no-defaults --user mysql --skip-grant-tables &
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
        bin/mysqld --no-defaults --user mysql &
        pid=$!
        while kill -0 $pid && [ ! -e /tmp/mysql.sock ]; do
            sleep 1
        done
        if kill -0 $pid; then
           break
        fi
    done
    # rewrite_example plugin よりも前に作っておく
    bin/mysql --no-defaults -e 'CREATE USER test IDENTIFIED BY "MySQL8.0"; GRANT ALL ON *.* TO test WITH GRANT OPTION'
    if [ -d lib/plugin ]; then
        for mod in $(cd lib/plugin; ls *.so | grep -v _client.so); do
            echo "[[[[ $mod ]]]]"
            case $mod in
                adt_null.so)
                    name=null_audit
                    ;;
                ha_example.so)
                    name=example
                    ;;
                ha_innodb_plugin.so)
                    name=innodb
                    ;;
                ha_mock.so)
                    name=mock
                    ;;
                innodb_engine.so)
                    name=innodb
                    ;;
                libdaemon_example.so)
                    name=daemon_example
                    ;;
                libmemcached.so)
                    name=daemon_memcached
                    ;;
                mypluglib.so)
                    name=simple_parser
                    ;;
                mysql_clone.so)
                    name=clone
                    ;;
                semisync_master.so)
                    name=rpl_semi_sync_master
                    ;;
                semisync_slave.so)
                    name=rpl_semi_sync_slave
                    ;;
                version_token.so)
                    name=version_tokens
                    ;;
                *)
                    name=${mod%.so}
                    ;;
            esac
            if [[ $mod =~ ^component ]]; then
                bin/mysql --no-defaults -e "install component 'file://${mod%.so}'" || true
            else
                bin/mysql --no-defaults -e "install plugin $name soname '$mod'" || true
            fi
        done
    fi
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
    /usr/local/mysql/bin/mysqld --no-defaults --user mysql --help -v > $CURDIR/mysqld/data/$ver.txt || true
    if [ -d /usr/local/mysql/lib/plugin ]; then
        plugin_load="$(grep -h ^plugin-load $CURDIR/mysqld/data/$ver.txt || true)"
        plugins=$(cd /usr/local/mysql/lib/plugin; ls *.so | grep -Ev '^component|client|innodb_engine|locking_service' | tr "\n" ";")
        /usr/local/mysql/bin/mysqld --no-defaults --plugin-load="$plugins" --user mysql --help -v > $CURDIR/mysqld/data/$ver.txt || true
        sed -i -e "s/^plugin-load .*$/$plugin_load/" $CURDIR/mysqld/data/$ver.txt
    fi
    start
    echo '----- SHOW GLOBAL VARIABLES -----' >> $CURDIR/mysqld/data/$ver.txt
    bin/mysql --no-defaults -N -e 'SHOW GLOBAL VARIABLES' | sort >> $CURDIR/mysqld/data/$ver.txt
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
    bin/mysql --no-defaults -e 'SHOW GRANTS FOR test' >> $CURDIR/privilege/data/$ver.txt
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
    bin/mysql --no-defaults -N information_schema -e "SELECT TABLE_NAME,COLUMN_NAME FROM COLUMNS WHERE TABLE_SCHEMA='information_schema'" | sort > $CURDIR/ischema/data/$ver.txt
}

p_pschema() {
    bin/mysql --no-defaults -N information_schema -e "SELECT TABLE_NAME,COLUMN_NAME FROM COLUMNS WHERE TABLE_SCHEMA='performance_schema'" | sort > $CURDIR/pschema/data/$ver.txt || true
}

p_error() {
    : > $CURDIR/error/data/$ver.txt
    grep '^#define ER_' include/mysqld_error.h | grep -Eo ' [0-9]+$' | while read e; do
        bin/perror $e 2> /dev/null | tr '\n' '\r' | sed -e 's/\r$/\n/' -e 's/\r/\\n/' >> $CURDIR/error/data/$ver.txt 2> /dev/null || true
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
