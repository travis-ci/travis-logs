-- Revert travis-logs:create_scan_results_table from pg

BEGIN;

  SET client_min_messages = WARNING;

  DROP TABLE scan_results;

COMMIT;
