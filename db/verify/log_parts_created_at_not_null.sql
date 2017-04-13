-- Verify travis-logs:log_parts_created_at_not_null on pg

BEGIN;

  SET client_min_messages = WARNING;

  INSERT INTO log_parts (log_id, content)
  VALUES (-1, 'flah');

  SELECT now() - created_at
  FROM log_parts
  WHERE log_id = -1;

  DELETE FROM log_parts
  WHERE log_id = -1;

ROLLBACK;
