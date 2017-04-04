-- Deploy travis-logs:log_parts_created_at_not_null to pg
-- requires: structure

BEGIN;

  ALTER TABLE log_parts
  ALTER COLUMN created_at
  SET DEFAULT '2000-01-01'::timestamptz;

  ALTER TABLE log_parts
  ALTER COLUMN created_at
  SET NOT NULL;

COMMIT;
