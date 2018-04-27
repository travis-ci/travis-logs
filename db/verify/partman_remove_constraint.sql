-- Verify travis-logs:partman_remove_constraint on pg

BEGIN;

  SET client_min_messages = WARNING;

  SELECT 1/count(*)
  FROM partman.part_config
  WHERE parent_table = 'public.log_parts'
  AND constraint_cols = '{}';

ROLLBACK;
