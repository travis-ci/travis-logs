-- Revert travis-logs:logs_create_scan_status from pg

BEGIN;

  SET client_min_messages = WARNING;

  ALTER TABLE logs
  DROP COLUMN scan_status,
  DROP COLUMN scan_status_updated_at,
  DROP COLUMN censored;

COMMIT;
