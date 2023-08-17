-- Verify travis-logs:logs_create_scan_status on pg

BEGIN;

  SET client_min_messages = WARNING;

  SELECT scan_status, scan_status_updated_at, censored, scan_queued_at, scan_started_at, scan_processing_at, scan_finalizing_at, scan_ended_at
  FROM logs
  WHERE false;

COMMIT;
