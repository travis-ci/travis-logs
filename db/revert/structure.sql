-- Revert travis-logs:structure from pg

BEGIN;

  DROP TABLE log_parts CASCADE;

  DROP TABLE logs CASCADE;

COMMIT;
