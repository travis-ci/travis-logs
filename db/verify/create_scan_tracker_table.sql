-- Verify travis-logs:create_scan_tracker_table on pg

BEGIN;

  SET client_min_messages = WARNING;

  SELECT id, scan_status, details, created_at
  FROM scan_tracker
  WHERE false;

COMMIT;
