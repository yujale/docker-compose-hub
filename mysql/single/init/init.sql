use mysql;
select 'host' from user where user='root';
update user set host = '%' where user ='root';
flush privileges;