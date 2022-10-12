-- Deploy travis-logs:create_scan_tracker_table to pg
-- requires: logs_create_scan_status

BEGIN;

  SET client_min_messages = WARNING;

  CREATE TABLE scan_tracker (
    id bigint NOT NULL,
    log_id bigint NOT NULL,
    scan_status character varying,
    details jsonb,
    created_at timestamp without time zone
  );

  CREATE SEQUENCE scan_tracker_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

  ALTER SEQUENCE scan_tracker_id_seq OWNED BY scan_tracker.id;

  ALTER TABLE ONLY scan_tracker
  ALTER COLUMN id
  SET DEFAULT nextval('scan_tracker_id_seq'::regclass);
  
  ALTER TABLE ONLY scan_tracker
  ADD CONSTRAINT scan_tracker_pkey PRIMARY KEY (id);

COMMIT;
