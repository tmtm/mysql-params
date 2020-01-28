#!/bin/bash
set -e

func() {
    tempfile=$(tempfile)
    bin/mysql --no-defaults -e "help $1" | grep '^  ' > $tempfile
    cat $tempfile | grep -iv 'functions\|operators' | sed -e 's/OPERATOR\|FUNCTION//' -e 's/^ *\| *$//' >> $CURDIR/function/data/$ver.txt || true
    cat $tempfile | grep -i 'functions\|operators' | while read l; do func "$l"; done
    rm -f $tempfile
}

CURDIR=$(pwd)
mkdir -p $CURDIR/{mysqld,mysql,charset,collation,status,privilege,function}/data
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
    /usr/local/mysql/bin/mysqld --no-defaults --help -v > $CURDIR/mysqld/data/$ver.txt || true
    sed -i -e "s/$(hostname)/hostname/g" $CURDIR/mysqld/data/$ver.txt
    /usr/local/mysql/bin/mysql --no-defaults --help -v > $CURDIR/mysql/data/$ver.txt || true
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
    bin/mysql --no-defaults -e 'SHOW CHARSET' > $CURDIR/charset/data/$ver.txt
    bin/mysql --no-defaults -e 'SHOW COLLATION' > $CURDIR/collation/data/$ver.txt
    bin/mysql --no-defaults -e 'SHOW GLOBAL STATUS' | awk '{print $1}' > $CURDIR/status/data/$ver.txt
    bin/mysql --no-defaults -e 'DESC mysql.user' > $CURDIR/privilege/data/$ver.txt
    bin/mysql --no-defaults -e 'DESC mysql.proxies_priv' >> $CURDIR/privilege/data/$ver.txt || true
    bin/mysql --no-defaults -e 'CREATE USER test; GRANT ALL ON *.* TO test WITH GRANT OPTION; SHOW GRANTS FOR test' >> $CURDIR/privilege/data/$ver.txt
    : > $CURDIR/function/data/$ver.txt
    func functions
    bin/mysql --no-defaults -N information_schema -e "SELECT TABLE_NAME,COLUMN_NAME FROM COLUMNS WHERE TABLE_SCHEMA='information_schema'" > $CURDIR/ischema/data/$ver.txt
    kill $pid
    while ps -p $pid; do
        sleep 1
    done
done
