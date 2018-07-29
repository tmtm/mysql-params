```
tar xf /foo/mysql-8.0.12-linux-glibc2.12-x86_64.tar.xz
sudo mv mysql-8.0.12-linux-glibc2.12-x86_64 /usr/local/mysql
sudo /usr/local/mysql/bin/mysqld --no-defaults --initialize
/usr/local/mysql/bin/mysqld --no-defaults --help -v > mysqld/8.0.12.txt
ruby ./tools/to_json.rb
```
