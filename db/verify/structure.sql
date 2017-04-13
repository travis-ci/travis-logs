-- Verify travis-logs:structure on pg

BEGIN;

  SET client_min_messages = WARNING;

  SELECT id, log_id, content, number, final, created_at
  FROM log_parts
  WHERE false;

  SELECT id, job_id, content, removed_by, created_at, updated_at,
    aggregated_at, archived_at, purged_at, removed_at, archiving,
    archive_verified
  FROM logs
  WHERE false;

ROLLBACK;
