-- Deploy travis-logs:partman_remove_constraint to pg
-- requires: partman

BEGIN;

  SET client_min_messages = WARNING;

  UPDATE partman.part_config
  SET constraint_cols = '{}'
  WHERE parent_table = 'public.log_parts';

COMMIT;
