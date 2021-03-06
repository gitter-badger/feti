﻿
/*
DROP
*/
drop table if exists course_provider_link;
DROP TABLE IF EXISTS campus_b;
drop table if exists provider_b;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS nqf;
DROP TABLE IF EXISTS nated;
DROP TABLE IF EXISTS ncv;
DROP TABLE IF EXISTS fos;
DROP TABLE IF EXISTS etqa;

DROP TABLE if exists feti_b;
DROP TABLE IF EXISTS addresse_centre;
DROP TABLE IF EXISTS course_master_id1;
DROP TABLE IF EXISTS provider_master_id1;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS provider_courses;
DROP TABLE IF EXISTS etqa_courses;
DROP TABLE IF EXISTS provider_etqa;

drop table if exists query;
drop table if exists etqa_status;

create table query (
	provider_master_id1 integer NOT NULL,
	provider_etqa_master_id integer,
	provider_etqa_master_status  character varying(255),
	provider_etqa_master_provider_etqa_id integer,
	provider_id integer,
	provider_name character varying(255),
	group_provider character varying(255),
	postal_address character varying(255),
	centre_address character varying(255),
	telephone_no character varying(255),
	house_number character varying(255),
	street_name character varying(255),
	suburb  character varying(255),
	city character varying(255),
	postal_code character varying(255),
	provider_etqa_id integer,
	etqas_providers_id integer,
	etqas_providers_etqa character varying(255),
	etqas_providers_researcher  character varying(255),
	etqas_provider_status  character varying(255),
	course_master_id1 integer,
	courses_etqa_master_id integer,
	courses_etqa_master_courses_id integer,
	qualifications_id integer,
	qual_code  character varying(255),
	qual_name character varying(255),
	nqf_level character varying(255),
	qual_type character varying(255),
	descriptor  character varying(255),
	specialisation character varying(255),
	field character varying(255),
	courses_id character varying(255),
	etqas_id character varying(255),
	etqa_id character varying(255),
	etqas_courses_etqa character varying(255),
	etqas_courses_researcher character varying(255)
);

COPY query FROM '/home/setup/combined_master_query.csv' DELIMITER ',' CSV HEADER;

create table etqa_status as
select provider_id, etqas_provider_status from query group by provider_id, etqas_provider_status;

/*
PROVIDER ETQA
*/
CREATE TABLE provider_etqa
(
  provider_id integer NOT NULL,
  provider_name character varying(255),
  provider_group character varying(255),
  email character varying(255),
  postal_address character varying(255),
  centre_address character varying(255),
  telephone character varying(255),
  room_floor character varying(255),
  building character varying(255),
  house_number character varying(255),
  street_name character varying(255),
  mini_suburb character varying(255),
  suburb character varying(255),
  city character varying(255),
  postal_code character varying(8),
  comments character varying(255),
  website character varying(255),
  contact_name character varying(255),
  contact_surname character varying(255),
  id integer NOT NULL,
  etqa_provider_id integer NOT NULL,
  old_street_data character varying(255),
  old_room_floor character varying(255),
  old_building character varying(255),
  old_house_number character varying(255),
  old_street_name character varying(255),
  old_suburb character varying(255),
  old_city character varying(255),
  old_postal_code character varying(255),
  CONSTRAINT provider_etqa_pkey PRIMARY KEY (id)
);

COPY provider_etqa FROM '/home/setup/provider_ETQA.csv' DELIMITER ',' CSV HEADER;

delete from provider_etqa where id >= 910 and id < 919;
delete from provider_etqa where id > 919 and id <= 931;

alter table provider_etqa add column geom geometry(Point,4326);
CREATE OR REPLACE FUNCTION get_geom(current_id integer) 
RETURNS geometry
AS
$BODY$
SELECT ST_SetSRID(ST_Force_2D(geom), 4326) AS geom FROM feti WHERE id = current_id
$BODY$
LANGUAGE SQL;
update provider_etqa set geom=get_geom(id);
drop function if exists get_geom(current_id integer);


create table addresse_centre(
centre character varying(255),
no_street character varying(255),
street_name character varying(255),
suburb character varying(255),
id integer
);
COPY addresse_centre FROM '/home/setup/addr_center.csv' DELIMITER '	' CSV HEADER;

--alter table feti add column center character varying(255);
--select * from feti, addresse_centre where feti.id = addresse_centre.id;

drop table if exists feti_b;
create table feti_b as
select f.id, centre, f.no_street, f.street_name, f.suburb, f.city, f.postal_code, f.geom from feti f, addresse_centre where f.id = addresse_centre.id;

/*
CAMPUS_B
*/
-- select provider_id as id, 0 as provider_id,
-- provider_id as campus_address_id,
DROP TABLE if exists campus_dup;
create table campus_dup as
select provider_etqa.id as id, 0 as provider_id, etqas_provider_status as status,
provider_etqa.id as campus_address_id,
centre as campus, f.no_street || ' ' || f.street_name as address1, f.suburb as address2, ''::text as address3, COALESCE(f.city, f.suburb) as town, f.postal_code, telephone as phone,
provider_etqa.geom as location,
provider_name as primary_institution
from provider_etqa, feti_b f, etqa_status
where provider_etqa.id = f.id
and provider_etqa.provider_id = etqa_status.provider_id
order by id;

drop table if exists campus_b;
create table campus_b as
select id, provider_id, status, campus_address_id, campus, address1, address2, address3, town, postal_code, phone, location, primary_institution
from campus_dup group by id, provider_id, status, campus_address_id, campus, address1, address2, address3, town, postal_code, phone, location, primary_institution;
drop table if exists campus_dup;

alter table campus_b add primary key (id);
update campus_b set primary_institution = address1 where primary_institution is null;


/*
PROVIDER_B
*/
drop table if exists provider_b;
create table provider_b (
	id serial,
	primary_institution character varying(255),
	website  character varying(255),
	status boolean
);
alter table provider_b add primary key(id);

CREATE OR REPLACE FUNCTION clean_status(status VARCHAR(50)) 
RETURNS boolean
AS
$BODY$
BEGIN
RETURN CASE
	WHEN status = 'Private' THEN False
	WHEN status = 'Public' THEN True
	ELSE True
END;
END
$BODY$
LANGUAGE PLPGSQL;

insert into provider_b (primary_institution, status)
select distinct primary_institution, clean_status(status) from campus_b;

drop function if exists clean_status(status VARCHAR(50)) ;

CREATE OR REPLACE FUNCTION get_fk(provider_name varchar(150)) 
RETURNS integer
AS
$BODY$
SELECT id FROM provider_b WHERE primary_institution = provider_name
$BODY$
LANGUAGE SQL;
update campus_b set provider_id=get_fk(primary_institution);
drop function if exists get_fk(provider_name varchar(150));

alter table campus_b drop column primary_institution;
alter table campus_b drop column status;
ALTER TABLE campus_b ADD FOREIGN KEY(provider_id) REFERENCES provider_b;


/*
Address
*/
DROP TABLE if exists address;
create table address as
select id as id, address1, address2, address3, town, postal_code, phone
from campus_b;

ALTER TABLE address ADD primary key(id);

update campus_b set campus = concat(address1, ' ', address2) where campus is null or campus =' ';

alter table campus_b add foreign key(campus_address_id) references address;

--select * from (select campus, count(*) as total from campus_b group by campus) as t where total > 1;


ALTER table campus_b drop column address1;
ALTER table campus_b drop column address2;
ALTER table campus_b drop column address3;
ALTER table campus_b drop column town;
ALTER table campus_b drop column postal_code;
ALTER table campus_b drop column phone;


/*
update address
*/
CREATE OR REPLACE FUNCTION clean_address2(addr2 VARCHAR(50), town VARCHAR(50)) 
RETURNS VARCHAR(50)
AS
$BODY$
BEGIN
RETURN CASE
	WHEN addr2 = town THEN ''
	WHEN addr2 != town THEN addr2
	ELSE addr2
END;
END
$BODY$
LANGUAGE PLPGSQL;
update address set address2=clean_address2(address2, town);
drop function if exists clean_address2(addr2 VARCHAR(50), town VARCHAR(50)) ;
UPDATE address SET postal_code = replace(postal_code,'?', '');

/*
ETQA
*/
CREATE TABLE etqa (
	id integer not null,
	etqa_acro character varying (255),
	etqa_full character varying (255),
	etqa_url character varying (255)
);
alter table etqa add primary key (id);
insert into etqa values(1,'kartoza', 'default value', 'default url');
COPY etqa FROM '/home/setup/etqa.csv' WITH (
   FORMAT csv,
   HEADER true
   );

/*
NQF
*/
create table nqf (nqf_level serial,nqf_desc character varying (255),nqf_cert character varying (255) ,nqf_link character varying (255));
COPY nqf FROM '/home/setup/nqf.csv' WITH (
   FORMAT csv,
   HEADER true
   );

alter table nqf add Primary Key (nqf_level);
SELECT setval('public.nqf_nqf_level_seq', 100);
--SELECT pg_get_serial_sequence('nqf', 'nqf_level')

/*
NATED
*/
create table nated (nated_level character varying (255),nated_descrip character varying (255));
COPY nated FROM '/home/setup/nated.csv' WITH (
   FORMAT csv,
   HEADER true
   );
ALTER TABLE nated ADD COLUMN "id" SERIAL PRIMARY KEY;

/*
NCV
*/
create table ncv (ncv_level integer ,ncv_descrip  character varying (255));
COPY ncv FROM '/home/setup/ncv.csv' WITH (
   FORMAT csv,
   HEADER true
   );
 alter table ncv add Primary Key (ncv_level);

/*
FOS
*/
create table fos (fos_class integer ,fos_descrip character varying (255));
COPY fos FROM '/home/setup/fos.csv' WITH (
   FORMAT csv,
   HEADER true
   );

alter table fos add Primary Key (fos_class);

/*
COURSES
*/
drop table if exists courses;
CREATE TABLE courses(
	qualifications_id integer,
	qual_code character varying(255),
	qual_name character varying(255),
	credits character varying(255),
	nqf_level character varying(255),
	qualification_type character varying(255),
	descriptor character varying(255),
	specialisation character varying(255),
	sub_specialisation character varying(255),
	field character varying(255),
	id integer NOT NULL,
	etqa_id integer,
	CONSTRAINT courses_pkey PRIMARY KEY (id)
);

COPY courses FROM '/home/setup/courses.csv' DELIMITER ',' CSV HEADER;


-- Cleaning the nqf_level column
ALTER TABLE courses ADD COLUMN nqf_level_clean character varying(255);
UPDATE courses SET nqf_level_clean = nqf_level;
UPDATE courses SET nqf_level_clean = substring(nqf_level_clean,5) where length(nqf_level_clean) = 5;
UPDATE courses SET nqf_level_clean = replace(nqf_level,'NQF Level', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level,'NQF', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level_clean,'LEVEL', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level_clean,'Level', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level_clean,'L', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level_clean,' ', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level_clean,'  ', '');
UPDATE courses SET nqf_level_clean = regexp_replace(nqf_level_clean,'\s+', '');
UPDATE courses SET nqf_level_clean = replace(nqf_level_clean, '0', '' ) WHERE nqf_level_clean LIKE '0%';

--deleting the replace the old column to get the FK
alter table courses drop column nqf_level;
alter table courses add column nqf_level integer;
CREATE OR REPLACE FUNCTION code_nqf(search_level VARCHAR(50)) 
RETURNS INTEGER
AS
$BODY$
SELECT nqf_level FROM nqf WHERE nqf_desc = search_level
$BODY$
LANGUAGE SQL;
update courses set nqf_level = code_nqf(nqf_level_clean);
drop function if exists code_nqf(search_level VARCHAR(50));

CREATE OR REPLACE FUNCTION code_nqf2(search_field VARCHAR(50)) 
RETURNS INTEGER
AS
$BODY$
BEGIN 
   RETURN CASE  
               WHEN search_field = '1' THEN 1
               WHEN search_field = '2' THEN 2
               WHEN search_field = '3' THEN 3
               WHEN search_field = '4' THEN 4
               WHEN search_field = '5' THEN 5
               WHEN search_field = '6' THEN 6
               WHEN search_field = '7' THEN 7
               WHEN search_field = '8' THEN 8
               WHEN search_field = '9' THEN 9
               WHEN search_field = '10' THEN 10
               ELSE null
          END;
END 
$BODY$
LANGUAGE PLPGSQL;
update courses set nqf_level = code_nqf2(nqf_level_clean) where nqf_level is null;
drop function if exists code_nqf2(search_field VARCHAR(50));

--update courses set nqf_level = NULLIF(nqf_level_clean, '')::int where nqf_level is null;

/*
NQF insert from COURSES to NQF
*/
DROP TABLE IF EXISTS temp_nqf;
CREATE TABLE temp_nqf AS 
	SELECT DISTINCT nqf_level_clean FROM courses ORDER BY nqf_level_clean;
	
delete from temp_nqf where nqf_level_clean = '1';
delete from temp_nqf where nqf_level_clean = '2';
delete from temp_nqf where nqf_level_clean = '3';
delete from temp_nqf where nqf_level_clean = '4';
delete from temp_nqf where nqf_level_clean = '5';
delete from temp_nqf where nqf_level_clean = '6';
delete from temp_nqf where nqf_level_clean = '7';
delete from temp_nqf where nqf_level_clean = '8';
delete from temp_nqf where nqf_level_clean = '9';
delete from temp_nqf where nqf_level_clean = '10';
delete from temp_nqf where nqf_level_clean LIKE '';
delete from temp_nqf where nqf_level_clean = '';
INSERT INTO nqf (nqf_desc)
	SELECT nqf_level_clean FROM temp_nqf;

delete from nqf where nqf_level=147;

/*end nqf*/

--Get the FK for the FOS field
alter table courses add column fos_id integer;
CREATE OR REPLACE FUNCTION code_field(search_field VARCHAR(50)) 
RETURNS INTEGER
AS
$BODY$
BEGIN 
   RETURN CASE  
               WHEN search_field = 'Education' THEN 5
               WHEN search_field = 'Engineering' THEN 6
               WHEN search_field = 'Business' THEN 3
               WHEN search_field = 'Art & Design' THEN 2
               WHEN search_field = 'IT' THEN 10
               WHEN search_field = 'Tourism & Hospitality' THEN 9
               WHEN search_field = 'Agriculture' THEN 1
               WHEN search_field = 'Services' THEN 11
               ELSE null
          END;
END 
$BODY$
LANGUAGE PLPGSQL;
update courses set fos_id = code_field(field);
drop function if exists code_field(search_field VARCHAR(50));

/*
COURSE
*/
drop table if exists course;
CREATE TABLE course AS
SELECT id, qual_code as nlrd, etqa_id AS etqa_id_old, qual_name as descriptor, nqf_level, 0 AS "nated_id", 0 AS "ncv_id", fos_id
FROM courses;
UPDATE course SET "nated_id" = NULL;
UPDATE course SET "ncv_id" = NULL;
--UPDATE course SET "fos_id" = NULL;
alter table course add primary key(id);
ALTER TABLE course ADD FOREIGN KEY(nqf_level) REFERENCES nqf;
ALTER TABLE course ADD FOREIGN KEY(nated_id) REFERENCES nated;
ALTER TABLE course ADD FOREIGN KEY(ncv_id) REFERENCES ncv;
ALTER TABLE course ADD FOREIGN KEY(fos_id) REFERENCES fos;

alter table course add column etqa_id integer;
CREATE OR REPLACE FUNCTION code_etqa(etqa_id_old INTEGER)
RETURNS INTEGER
AS
$BODY$
BEGIN
   RETURN CASE
               WHEN etqa_id_old = 1 THEN 1
               WHEN etqa_id_old = 2 THEN 10
               WHEN etqa_id_old = 3 THEN 11
               WHEN etqa_id_old = 4 THEN 12
               WHEN etqa_id_old = 5 THEN 13
               WHEN etqa_id_old = 6 THEN 14
               WHEN etqa_id_old = 7 THEN 15
               WHEN etqa_id_old = 8 THEN 16
               WHEN etqa_id_old = 9 THEN 17
               WHEN etqa_id_old = 10 THEN 18
               WHEN etqa_id_old = 11 THEN 19
               WHEN etqa_id_old = 12 THEN 2
               WHEN etqa_id_old = 13 THEN 20
               WHEN etqa_id_old = 14 THEN 21
               WHEN etqa_id_old = 15 THEN 22
               WHEN etqa_id_old = 16 THEN 23
               WHEN etqa_id_old = 17 THEN 24
               WHEN etqa_id_old = 18 THEN 25
               WHEN etqa_id_old = 19 THEN 26
               WHEN etqa_id_old = 20 THEN 3
               WHEN etqa_id_old = 21 THEN 4
               WHEN etqa_id_old = 22 THEN 5
               WHEN etqa_id_old = 23 THEN 6
               WHEN etqa_id_old = 24 THEN 7
               WHEN etqa_id_old = 25 THEN 8
               WHEN etqa_id_old = 26 THEN 9
               WHEN etqa_id_old = 27 THEN 27
               WHEN etqa_id_old = 28 THEN 28
               ELSE null
          END;
END
$BODY$
LANGUAGE PLPGSQL;
update course set etqa_id = code_etqa(etqa_id_old);
drop function if exists code_etqa(etqa_id_old INTEGER);

ALTER TABLE course ADD FOREIGN KEY(etqa_id) REFERENCES etqa;

/*
COURSE MASTER ID1
*/
CREATE TABLE course_master_id1
(
  course_master_id integer NOT NULL,
  id integer,
  enrolled character varying(255),
  wrote_exams character varying(255),
  passed character varying(255),
  status character varying(255),
  providers_id integer,
  courses_id integer,
  CONSTRAINT course_master_id1_pkey PRIMARY KEY (course_master_id)
);

COPY course_master_id1 FROM '/home/setup/courses_ETQA_master.csv' DELIMITER ',' CSV HEADER;


/*
course_provider_link
*/

drop table if exists course_provider_link;
CREATE TABLE course_provider_link (
	id serial primary key,
	campus_id integer,
	course_id integer
);

/*
PROVIDER MASTER ID1
*/
drop table if exists provider_master_id1;
CREATE TABLE provider_master_id1
(
  provider_master_id integer NOT NULL,
  id integer,
  enrolled character varying(255),
  wrote_exams character varying(255),
  passed character varying(255),
  status character varying(255),
  qualifications_id integer,
  qual_code character varying(255),
  qual_name character varying(255),
  credits character varying(255),
  nqf_level character varying(255),
  qualification_type character varying(255),
  descriptor character varying(255),
  specialisation character varying(255),
  field character varying(255),
  provider_etqa_id integer,
  CONSTRAINT provider_master_id1_pkey PRIMARY KEY (provider_master_id)
);

COPY provider_master_id1 FROM '/home/setup/provider_ETQA_master.csv' DELIMITER ',' CSV HEADER;

-- USING QUALIFICATIONS_ID
/*
insert into course_provider_link (campus_id, course_id)
select provider_etqa.id as provider_id_alias, courses.id as id_course
from provider_master_id1, provider_etqa, courses
where provider_etqa.id = provider_master_id1.provider_etqa_id
and provider_master_id1.qualifications_id = courses.qualifications_id
order by id_course; --7967 rows
*/
-- USING RELATIONS
insert into course_provider_link (campus_id, course_id)
select provider_etqa.id as provider_id_alias, courses.id as id_course
from provider_etqa, provider_master_id1, course_master_id1, courses
where provider_etqa.id = provider_master_id1.provider_etqa_id
and provider_master_id1.provider_master_id = course_master_id1.course_master_id
and course_master_id1.courses_id = courses.id
order by id_course; --7934 rows

ALTER TABLE course_provider_link ADD FOREIGN KEY(campus_id) REFERENCES campus_b;
ALTER TABLE course_provider_link ADD FOREIGN KEY(course_id) REFERENCES course;

/*
ETQA courses
*/
CREATE TABLE etqa_courses(
	etqa_id integer NOT NULL,
	etqa character varying(255),
	id integer NOT NULL,
	researcher character varying(255),
	CONSTRAINT etqa_courses_pkey PRIMARY KEY (etqa_id)
);

COPY etqa_courses FROM '/home/setup/ETQAs_Courses.csv' DELIMITER ',' CSV HEADER;


/*
PROVIDER COURSES
*/

CREATE TABLE provider_courses
(
  provider_id integer NOT NULL,
  provider_name character varying(255),
  email character varying(255),
  postal_address character varying(255),
  centre_address character varying(255),
  telephone character varying(255),
  house_number character varying(255),
  street_name character varying(255),
  suburb character varying(255),
  postal_code character varying(8),
  website character varying(255),
  contact_name character varying(255),
  contact_surname character varying(255),
  id integer NOT NULL,
  CONSTRAINT provider_courses_pkey PRIMARY KEY (provider_id)
);

COPY provider_courses FROM '/home/setup/providers_courses.csv' DELIMITER ',' CSV HEADER;

/*
mapping to the django tables
*/

truncate feti_courseproviderlink, feti_campus, feti_provider, feti_address CASCADE;

insert into feti_address
select * from address;

insert into feti_provider
select id, primary_institution, '', status from provider_b;

insert into feti_campus
select id, campus, location, campus_address_id, provider_id, campus, True from campus_b;



truncate feti_course, feti_educationtrainingqualityassurance, feti_fieldofstudy, feti_nationalqualificationsframework, feti_campus_courses CASCADE;

update etqa set etqa_full = etqa_acro where etqa_full is null;
insert into feti_educationtrainingqualityassurance
select * from etqa;

insert into feti_fieldofstudy
select fos_class, fos_class, fos_descrip from fos;

update nqf set nqf_cert = '####' where nqf_cert is null;

insert into feti_nationalqualificationsframework
select * from nqf;

insert into feti_course 
select id, nlrd, descriptor, etqa_id, fos_id, nated_id, ncv_id, nqf_level, descriptor from course;

truncate feti_campus_courses;
insert into feti_campus_courses (campus_id, course_id)
select campus_id, course_id from course_provider_link group by campus_id, course_id;


drop table if exists course_provider_link;
drop table if exists campus_b;
drop table if exists temp_nqf;
drop table if exists address;
drop table if exists addresse_centre;
drop table if exists course;
drop table if exists course_master_id1;
drop table if exists courses;
drop table if exists etqa;
drop table if exists etqa_courses;
drop table if exists feti;
drop table if exists query;
drop table if exists tmp;
drop table if exists etqa_status;
drop table if exists feti_b;
drop table if exists fos;
drop table if exists nated;
drop table if exists ncv;
drop table if exists nqf;
drop table if exists provider;
drop table if exists provider_courses;
drop table if exists provider_b;
drop table if exists provider_etqa;
drop table if exists provider_master_id1;
