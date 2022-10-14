-- Verify travis-logs:create_scan_results_table on pg

BEGIN;

  SET client_min_messages = WARNING;

  SELECT id
  FROM scan_results
  WHERE false;

ROLLBACK;
