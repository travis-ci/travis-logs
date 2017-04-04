-- Revert travis-logs:structure from pg

BEGIN;

  SET client_min_messages = WARNING;

  DROP TABLE log_parts CASCADE;

  DROP TABLE logs CASCADE;

COMMIT;
