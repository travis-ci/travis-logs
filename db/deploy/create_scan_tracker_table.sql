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

COMMIT;
