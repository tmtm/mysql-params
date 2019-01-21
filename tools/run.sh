#!/bin/bash
set -e

CURDIR=$(pwd)
for tar in "$@"; do
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
    chown -R mysql. /usr/local/mysql
    /usr/local/mysql/bin/mysqld --no-defaults --help -v > $CURDIR/mysqld/$ver.txt || true
done
