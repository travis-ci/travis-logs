-- Revert travis-logs:create_scan_tracker_table from pg

BEGIN;

  SET client_min_messages = WARNING;

  DROP TABLE scan_tracker CASCADE;

COMMIT;
