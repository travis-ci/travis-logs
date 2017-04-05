-- Deploy travis-logs:partman to pg
-- requires: log_parts_created_at_not_null

BEGIN;

  SET client_min_messages = WARNING;

  CREATE SCHEMA IF NOT EXISTS partman;

  CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;

  SELECT partman.create_parent(
    'public.log_parts',
    'created_at',
    'time',
    'daily',
    p_constraint_cols := '{"log_id"}',
    p_premake := 2
  );

  UPDATE partman.part_config
  SET retention = '3 days',
      retention_keep_table = false,
      retention_keep_index = false,
      optimize_trigger = 2,
      optimize_constraint = 2
  WHERE parent_table = 'public.log_parts';

COMMIT;
