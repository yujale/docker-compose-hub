create user 'rep'@'%' identified with 'mysql_native_password' by 'rootroot';
grant replication slave,replication client on *.* to 'rep'@'%';
flush privileges;