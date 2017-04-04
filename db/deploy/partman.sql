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
    p_constraint_cols := '{"log_id"}'::text[],
    p_premake := 2,
    p_upsert := 'ON CONFLICT(id) DO UPDATE SET val=EXCLUDED.val'
  );

  UPDATE partman.part_config
  SET retention = '2 days'
  WHERE parent_table = 'public.log_parts';

COMMIT;
