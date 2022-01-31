create table if not exists users(
`login` varchar(50) primary key,
`hash` varchar(64),
`state` int(1),
`lastdate` datetime,
`hashdate` datetime,
lastip int(4) unsigned
);

create table if not exists auth_log(
`login` varchar(50) primary key,
`ip` int(4) unsigned,
`log` varchar(64),
`timestamp` datetime
);

create table if not exists state(
id int primary key,
state int,
dat datetime
);

insert into state (id,state,dat) values (1,1,now());

