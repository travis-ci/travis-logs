-- Revert travis-logs:logs_create_scan_status from pg

BEGIN;

  SET client_min_messages = WARNING;

  ALTER TABLE logs
  DROP COLUMN scan_status,
  DROP COLUMN scan_status_updated_at,
  DROP COLUMN censored,
  DROP COLUMN scan_queued_at,
  DROP COLUMN scan_started_at,
  DROP COLUMN scan_processing_at,
  DROP COLUMN scan_finalizing_at,
  DROP COLUMN scan_ended_at;

  DROP INDEX index_logs_on_scan_status_and_id_desc;
  DROP INDEX index_logs_on_scan_status_and_scan_status_updated_at;
  DROP INDEX index_logs_on_scan_status_and_created_at_desc;

COMMIT;
