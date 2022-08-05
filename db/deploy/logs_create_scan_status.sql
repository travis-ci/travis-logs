-- Deploy travis-logs:logs_create_scan_status to pg
-- requires: partman_remove_constraint

BEGIN;

  SET client_min_messages = WARNING;

  ALTER TABLE logs
  ADD COLUMN scan_status character varying,
  ADD COLUMN scan_status_updated_at timestamp without time zone,
  ADD COLUMN censored boolean DEFAULT false;

COMMIT;
