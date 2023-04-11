--these tables will not be used, so drop their contents 
truncate table concept_proposal;
truncate table hl7_in_archive;
truncate table hl7_in_error;
truncate table hl7_in_queue;
truncate table formentry_error;
truncate table user_property;
truncate table notification_alert_recipient;
truncate table notification_alert;

-- dummy values are entered into these tables later
truncate table patient_identifier;
truncate table patient_identifier_type;

--clear out the username/password stored in the db
update global_property set property_value = 'admin' where property like '%.username';
update global_property set property_value = 'test' where property like '%.password';

--
-- randomize the person names in the database
-- 
drop table if exists random_names;

CREATE TABLE `random_names` (
	`rid` int(11) NOT NULL auto_increment,
	`name` varchar(255) NOT NULL,
	PRIMARY KEY  (`rid`),
	UNIQUE KEY `name` (`name`),
	UNIQUE KEY `rid` (`rid`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

-- make the randome names table hold all unique first/middle/last names
insert into random_names (name, rid) select distinct(trim(given_name)) as name, null from person_name where given_name is not null and not exists (select * from random_names where name = trim(given_name));
insert into random_names (name, rid) select distinct(trim(middle_name)) as name, null from person_name where middle_name is not null and not exists (select * from random_names where name = trim(middle_name));
insert into random_names (name, rid) select distinct(trim(family_name)) as name, null from person_name where family_name is not null and not exists (select * from random_names where name = trim(family_name));

drop procedure if exists randomize_names;
delimiter //
create procedure randomize_names()
begin
	set @size = (select max(person_name_id) from person_name);
	set @start = 0;
	-- if stepsize is increased, you should increase "limit 300" below as well
	set @stepsize = 300; 
	while @start < @size do
		update
			person_name
		set
			given_name = (select
									name
								from
									(select
										rid
										from
										random_names
										order by
										rand()
										limit 300
									) rid,
									random_names rn
								where	
									rid.rid = rn.rid
								order by
									rand()
								limit 1
							),
						middle_name = given_name,
						family_name = middle_name
		where
			person_name_id between @start and (@start + @stepsize);
		
		set @start = @start + @stepsize +1;
	end while;
end;
//
delimiter ;
call randomize_names();
drop procedure if exists randomize_names;

--
-- Randomize the birth dates and months (leave years the same)
--

-- this query randomizes the month, then the day as opposed to the later ones that just randomizes on month*days
--update person set birthdate = date_add(date_add(birthdate, interval cast(rand()*12-12 as signed) month),interval cast(rand()*30-30 as signed) day) where birthdate is not null;

-- randomize +/- 6 months for persons older than ~15 yrs old
update person set birthdate = date_add(birthdate, interval cast(rand()*182-182 as signed) day) where birthdate is not null and datediff(now(), birthdate) > 15*365;

-- randomize +/- 3 months for persons between 15 and 5 years old
update person set birthdate = date_add(birthdate, interval cast(rand()*91-91 as signed) day) where birthdate is not null and datediff(now(), birthdate) between 15*365 and 5*365;

-- randomize +/- 30 days for persons less than ~5 years old
update person set birthdate = date_add(birthdate, interval cast(rand()*30-30 as signed) day) where birthdate is not null and datediff(now(), birthdate) < 5*365;

update person set birthdate_estimated = cast(rand() as signed);

-- randomize the death date +/- 3 months
update 
	person
set
	death_date = date_add(death_date, interval cast(rand()*91-91 as signed) day)
where 
	death_date is not null;

--
-- Randomize the encounter and obs dates
--
drop table if exists random_enc_dates;

CREATE TABLE `random_enc_dates` (
	`eid` int(11) NOT NULL auto_increment,
	`orig_encounter_datetime` datetime NOT NULL,
	`rand_encounter_datetime` datetime NOT NULL,
	PRIMARY KEY  (`eid`),
	UNIQUE KEY `rid` (`eid`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

insert into 
	random_enc_dates
	(eid, orig_encounter_datetime, rand_encounter_datetime)
	select
		encounter_id,
		encounter_datetime,
		adddate(encounter_datetime, cast(rand()*91-91 as signed))
	from
		encounter;
		
-- change all encounter_datetime values to the random value
update 
  encounter e
  join random_enc_dates rand on e.encounter_id = rand.eid
set 
	e.encounter_datetime = rand_encounter_datetime,
	e.date_created = rand_encounter_datetime;

-- move the datetime of all obs that have that DO NOT have the same datetime as the 
-- encounter to the encounter's new datetime
-- THIS MUST BE RUN BEFORE THE "change all obs that have hte same datetime" query is run
update
	obs o
	join random_enc_dates rand on o.encounter_id = rand.eid
set
	o.obs_datetime = adddate(o.obs_datetime, datediff(rand_encounter_datetime, orig_encounter_datetime)),
	o.date_created = o.obs_datetime
where
	o.obs_datetime <> orig_encounter_datetime;
	
-- change all obs that have that have the same datetime as the 
-- encounter to the encounter's new datetime
update
	obs o
	join random_enc_dates rand on o.encounter_id = rand.eid
set
	o.obs_datetime = rand.rand_encounter_datetime,
	o.date_created = o.obs_datetime
where
	o.obs_datetime = rand.orig_encounter_datetime;

-- randomize all obs that have no encounter
update
	obs o
set
	o.obs_datetime = adddate(obs_datetime, cast(rand()*90-90 as signed)),
	o.date_created = o.obs_datetime
where
	o.encounter_id is null;

-- move all value_datetime according to how the obs_datetime was moved
update
	obs o
	join random_enc_dates rand on o.encounter_id = rand.eid
set
	o.value_datetime = adddate(o.value_datetime, datediff(rand_encounter_datetime, orig_encounter_datetime))
where
	o.value_datetime is not null;

-- simply randomize all non-encounter based obs value_datetimes
update
	obs o
set
	o.value_datetime = adddate(obs_datetime, cast(rand()*91-91 as signed))
where
	o.value_datetime is not null
	and
	encounter_id is null;


drop table if exists random_enc_dates;

--
-- Randomize the transfer location dates 
-- 
set @health_center_id = (select person_attribute_type_id from person_attribute_type where name = 'Health Center');
update 
	person_attribute
set
	date_created = date_add(date_created, interval cast(rand()*91-91 as signed) day)
where
	person_attribute_type_id = @health_center_id;

set @race_id = (select person_attribute_type_id from person_attribute_type where name = 'Race');
delete from
	person_attribute
where
	person_attribute_type_id = @race_id;

set @birthplace_id = (select person_attribute_type_id from person_attribute_type where name = 'Birthplace');
delete from
	person_attribute
where
	person_attribute_type_id = @birthplace_id;

--
-- Rename location to something nonsensical
--
update
	location
set
	name = concat('Location-', location_id);
	
-- 
-- Dumb-ify the identifiers
-- (assumes patient_identifier_type and patient_identifier
-- have been truncated
-- 
insert into
	patient_identifier_type
	(name, description, check_digit, creator, date_created, required, retired)
values
	('Dummy Identifier', '', 0, 1, '20080101', 0, 0);

insert into 
	patient_identifier
	(patient_id, identifier, identifier_type, location_id, preferred, creator, date_created, voided)
select
	patient_id,
	concat('ident-', patient_id),
	1,
	1,
	1,
	1,
	'20080101',
	0
from
	patient;

	
-- 
-- Dumbify the usernames and clear out login info
--
update
	users
set
	username = concat('username-', user_id);

update users set password = '4a1750c8607dfa237de36c6305715c223415189';
update users set salt = 'c788c6ad82a157b712392ca695dfcf2eed193d7f';
update users set secret_question = null;
update users set secret_answer = null;

--
-- Shift the person addresses around
--
update 
	person_address
set
	address1 = concat(person_id, ' address1'),
	address2 = concat(person_id, ' address2'),
	latitude = null,
	longitude = null,
	neighborhood_cell = concat(person_id, ' cell'),
	date_created = now(),
	date_voided = now();


