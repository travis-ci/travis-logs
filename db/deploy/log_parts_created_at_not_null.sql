-- Deploy travis-logs:log_parts_created_at_not_null to pg
-- requires: structure

BEGIN;

  SET client_min_messages = WARNING;

  ALTER TABLE log_parts
  ALTER COLUMN created_at
  SET DEFAULT '2000-01-01'::timestamp;

  ALTER TABLE log_parts
  ALTER COLUMN created_at
  SET NOT NULL;

COMMIT;
