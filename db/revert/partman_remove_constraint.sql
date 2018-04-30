-- Revert travis-logs:partman_remove_constraint from pg

BEGIN;

  SET client_min_messages = WARNING;

  UPDATE partman.part_config
  SET constraint_cols = '{log_id}'
  WHERE parent_table = 'public.log_parts';

COMMIT;
