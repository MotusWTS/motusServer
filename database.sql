create database motus;
create user motus@localhost identified by 'summer';
grant all privileges on motus.* to motus@localhost;
flush privileges;
quit;
