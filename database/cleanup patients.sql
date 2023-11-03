set foreign_key_checks=0;

truncate table test_order;
truncate table drug_order;
truncate table note;
truncate table concept_proposal;
truncate table concept_proposal_tag_map;
truncate table obs;
truncate table orders;
truncate table drug_order;
truncate table test_order;
truncate table relationship;
truncate table visit_attribute;
truncate table encounter_provider;
truncate table order_group;
truncate table encounter;
truncate table patient_appointment;
truncate table patient_appointment_audit;
truncate table patient_appointment_occurrence;
truncate table patient_appointment_provider;
truncate table patient_appointment_recurring_time;
truncate table visit_attribute;
truncate table visit;
truncate table patient_identifier;
truncate table conditions;
truncate table cohort_member;
truncate table patient_program;
truncate table patient_program_attribute;
truncate table patient_state;
truncate table patient;
delete from person_address where person_id <> 1;
delete from person_attribute where person_id <> 1;
delete from person_name where not exists
	(select u.person_id from users u where person_name.person_id = u.person_id or person_name.person_id = 1)
	and not exists (select p.person_id from provider p where person_name.person_id = p.person_id or person_name.person_id = 1);
delete from person where not exists
	(select u.person_id from users u where person.person_id = u.person_id or person.person_id = 1)
	and not exists (select p.person_id from provider p where person.person_id = p.person_id or person.person_id = 1);


update idgen_seq_id_gen set next_sequence_value = 1;

set foreign_key_checks=1;