-- Revert travis-logs:log_parts_created_at_not_null from pg

BEGIN;

  ALTER TABLE log_parts
  ALTER COLUMN created_at
  DROP NOT NULL;

  ALTER TABLE log_parts
  ALTER COLUMN created_at
  DROP DEFAULT;

COMMIT;
