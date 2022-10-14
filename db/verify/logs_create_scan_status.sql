-- Verify travis-logs:logs_create_scan_status on pg

BEGIN;

  SET client_min_messages = WARNING;

  SELECT scan_status, scan_status_updated_at, censored
  FROM logs
  WHERE false;

COMMIT;
