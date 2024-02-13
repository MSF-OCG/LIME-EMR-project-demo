SET
   FOREIGN_KEY_CHECKS = 0;
-- these TABLEs will not be used, so drop their contents
TRUNCATE TABLE concept_proposal_tag_map;
TRUNCATE TABLE concept_proposal;
TRUNCATE TABLE hl7_in_archive;
TRUNCATE TABLE hl7_in_error;
TRUNCATE TABLE hl7_in_queue;
TRUNCATE TABLE notification_alert_recipient;
TRUNCATE TABLE notification_alert;
SET
   FOREIGN_KEY_CHECKS = 1;
-- randomize the person names (given_name and family_name to contain random 8 alpha-numeric characters)
UPDATE
   person_name
SET
   given_name = concat( 'AnonFN', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) ),
   family_name = concat( 'AnonLN', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

-- randomize +/- 6 months for persons older than ~15 yrs old
UPDATE
   person
SET
   birthdate = date_add(birthdate, interval cast(rand()* 182 - 182 as signed) day)
WHERE
   birthdate is not null
   and datediff(now(), birthdate) > 15 * 365;
-- randomize +/- 3 months for persons between 15 and 5 years old
UPDATE
   person
SET
   birthdate = date_add(birthdate, interval cast(rand()* 91 - 91 as signed) day)
WHERE
   birthdate is not null
   and datediff(now(), birthdate) between 15 * 365 and 5 * 365;
-- randomize +/- 30 days for persons less than ~5 years old
UPDATE
   person
SET
   birthdate = date_add(birthdate, interval cast(rand()* 30 - 30 as signed) day)
WHERE
   birthdate is not null
   and datediff(now(), birthdate) < 5 * 365;
UPDATE
   person
SET
   birthdate_estimated = cast(rand() as signed);
-- randomize the death date +/- 3 months
UPDATE
   person
SET
   death_date = date_add(death_date, interval cast(rand()* 91 - 91 as signed) day)
WHERE
   death_date is not null;

-- set opposite gender
UPDATE
   person
SET
   gender =
   case
   when gender = 'F' then 'M'
   when gender = 'M' then 'F'
   end;
--
-- Clear out login info
--
UPDATE
   users
SET
   username = concat( 'AnonUSR', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) ),
   password = '36ee23ea83437a6954bc35f6bb1ca7c564d9e096bf49180414cb3a38faca0f53be74afec961ccb0311d3125bc9310ca9cec98afa0510d2e62f2812e418b571a5',
   salt = '26a1b70790d383ffdb2f035a7f90b25794273b8a3f0104b0776db42cb4c98144c3e1e642282b2ec73b240957bcba48ca99bef1954b09d9090e681a584fd20ad7',
   secret_question = null,
   secret_answer = null
WHERE
   username NOT IN
   (
      'admin',
      'superman',
      'reports-user',
      'superman'
   )
;
-- clear out the username/password stored IN the db
UPDATE
   global_property
SET
   property_value = 'admin'
WHERE
   property like '%.username';
UPDATE
   global_property
SET
   property_value = 'test'
WHERE
   property like '%.password';
-- Clearing out all the user properties except favouriteObsTemplates
DELETE
FROM
   user_property
WHERE
   property NOT IN
   (
      'favouriteObsTemplates'
   )
;
--
-- Shift the person addresses around
--
UPDATE
   person_address
SET
   address1 = concat('anon-address1-', person_id),
   address2 = concat('anon-address2-', person_id),
   address3 = concat('anon-address3-', person_id),
   address4 = concat('anon-address4-', person_id),
   address5 = concat('anon-address5-', person_id),
   address6 = concat('anon-address6-', person_id),
   county_district = concat('anon-countyDistrict', person_id),
   city_village = concat('anon-cityVillage', person_id),
   country = concat('anon-country', person_id),
   state_province = null,
   postal_code = null,
   latitude = null,
   longitude = null,
   date_created = now(),
   date_voided = now();
--
-- Bahmni customized
--
-- identifiers (Assumes patient_identifier have been TRUNCATED)
CREATE TABLE temp_patient_identifier_old(patient_id int, identifier varchar(256), PRIMARY KEY(patient_id));
INSERT INTO
   temp_patient_identifier_old
   SELECT
      patient_id,
      identifier
   FROM
      patient_identifier;
TRUNCATE patient_identifier;
INSERT INTO
   patient_identifier (patient_id, identifier, identifier_type, location_id, preferred, creator, date_created, voided, uuid)
   SELECT
      patient_id,
      concat('AN', patient_id),
      (
         Select
            patient_identifier_type_id
         FROM
            patient_identifier_type
         WHERE
            name = 'Patient Identifier'
      ),
      3,
      1,
      1,
      (
         SELECT
            timestamp(now()) - INTERVAL FLOOR( RAND( ) * 366) DAY
      ),
      0,
      uuid()
   FROM
      patient;
CREATE TABLE temp_person_uuid_old(person_id int, uuid varchar(256), PRIMARY KEY(person_id));
INSERT INTO
   temp_person_uuid_old
   SELECT
      person_id,
      uuid
   FROM
      person;
DROP TABLE temp_patient_identifier_old;
DROP TABLE temp_person_uuid_old;

--
-- Bahmni specific (i have disabled it at the moment)
--
-- TRUNCATE failed_events;


/* Database restoring issue with definer */
UPDATE
   `mysql`.`proc`
SET
   definer = 'openmrs-user@localhost'
WHERE
   definer like 'openmrs-user@%';
--
-- Bangladesh specific
--
/* for all person attribute WHERE Camp location is getting captured */

UPDATE
  person_attribute pa
  INNER JOIN
     person_attribute_type pat
     ON pat.person_attribute_type_id = pa.person_attribute_type_id
     AND pat.name LIKE '%Camp location%'
     AND pat.format = 'java.lang.String'
SET
  pa.value = concat('anon-', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

/* for all person attribute WHERE Mazhi is getting captured */

  UPDATE
    person_attribute pa
    INNER JOIN
       person_attribute_type pat
       ON pat.person_attribute_type_id = pa.person_attribute_type_id
       AND pat.name LIKE '%Mazhi%'
       AND pat.format = 'java.lang.String'
  SET
    pa.value = concat('anon-', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

/* for all person attribute WHERE Status of Patient is getting captured */

  UPDATE
    person_attribute pa
    INNER JOIN
       person_attribute_type pat
       ON pat.person_attribute_type_id = pa.person_attribute_type_id
       AND pat.name LIKE '%Status of Patient%'
       AND pat.format = 'org.openmrs.Concept'
  SET
    pa.value =
    case
    when pa.value = 201 then 200
    when pa.value = 200 then 201
    end;

/* for all person attribute WHERE Patient phone number is getting captured */

  UPDATE
    person_attribute pa
    INNER JOIN
       person_attribute_type pat
       ON pat.person_attribute_type_id = pa.person_attribute_type_id
       AND pat.name LIKE '%Patient phone number%'
       AND pat.format = 'java.lang.String'
  SET
      pa.value = concat('+', FLOOR(RAND() * 100000000));
  /* for all person attribute WHERE Previous MSF ID is getting captured */

  UPDATE
    person_attribute pa
    INNER JOIN
       person_attribute_type pat
       ON pat.person_attribute_type_id = pa.person_attribute_type_id
       AND pat.name LIKE '%Previous MSF ID%'
       AND pat.format = 'java.lang.String'
  SET
      pa.value = concat('anon-', FLOOR(RAND() * 100000000));
  /* for all person attribute WHERE Full name is getting captured */

    UPDATE
      person_attribute pa
      INNER JOIN
         person_attribute_type pat
         ON pat.person_attribute_type_id = pa.person_attribute_type_id
         AND pat.name LIKE '%Full name%'
         AND pat.format = 'java.lang.String'
    SET
      pa.value = concat('anon-', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

  /* for all person attribute WHERE Relationship with the patient is getting captured */

    UPDATE
      person_attribute pa
      INNER JOIN
         person_attribute_type pat
         ON pat.person_attribute_type_id = pa.person_attribute_type_id
         AND pat.name LIKE '%Relationship with the patient%'
         AND pat.format = 'java.lang.String'
    SET
      pa.value = concat('anon-', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

  /* for all person attribute WHERE Phone number is getting captured */

    UPDATE
      person_attribute pa
      INNER JOIN
         person_attribute_type pat
         ON pat.person_attribute_type_id = pa.person_attribute_type_id
         AND pat.name LIKE '%Phone number%'
         AND pat.format = 'java.lang.String'
    SET
      pa.value = concat('+', FLOOR(RAND() * 100000000));

  /* for all person attribute WHERE Address is getting captured */

    UPDATE
      person_attribute pa
      INNER JOIN
         person_attribute_type pat
         ON pat.person_attribute_type_id = pa.person_attribute_type_id
         AND pat.name LIKE '%Address%'
         AND pat.format = 'java.lang.String'
    SET
      pa.value = concat('anon-', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

  /* for all person attribute WHERE Block number is getting captured */

    UPDATE
      person_attribute pa
      INNER JOIN
         person_attribute_type pat
         ON pat.person_attribute_type_id = pa.person_attribute_type_id
         AND pat.name LIKE '%Block number%'
         AND pat.format = 'java.lang.String'
    SET
      pa.value = concat('anon-', FLOOR(RAND() * 100000000));

/*  Appointment scheduling Notes */
UPDATE
   patient_appointment
SET
   comments = CONCAT('anon-AppointmentComments', char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97), char(round(rand()* 25) + 97) );

/*  as the following comments and notes fields having some sensitive info */

UPDATE
   obs
SET
   value_text = 'anonimized comment'
WHERE
   concept_id IN
   (
      SELECT
         concept_id
      FROM
         concept
      WHERE
         datatype_id = 3
   )
;
UPDATE
   obs
SET
   comments = 'anon-TestNotes'
WHERE
   comments is not null;