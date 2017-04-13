-- Revert travis-logs:partman from pg

BEGIN;

  -- NOTE: In order for the partitions to be rolled back into the parent table
  -- properly, the undo_partition.py script should be used, which is at:
  -- https://raw.githubusercontent.com/keithf4/pg_partman/master/bin/undo_partition.py

  SET client_min_messages = WARNING;

  SELECT partman.undo_partition('public.log_parts', 4, false);

  DROP SCHEMA partman CASCADE;

COMMIT;
