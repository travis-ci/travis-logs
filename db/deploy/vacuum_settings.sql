-- Deploy travis-logs:vacuum_settings to pg
-- requires: structure

BEGIN;

  SET client_min_messages = WARNING;

  ALTER TABLE log_parts
  SET (autovacuum_vacuum_threshold = 0);

  ALTER TABLE log_parts
  SET (autovacuum_vacuum_scale_factor = 0.001);

  DO $$
    BEGIN
      EXECUTE 'ALTER DATABASE ' ||
        current_database() ||
        ' SET vacuum_cost_limit = 10000';
    END;
  $$;

  DO $$
    BEGIN
      EXECUTE 'ALTER DATABASE ' ||
        current_database() ||
        ' SET vacuum_cost_delay = 20';
    END;
  $$;

COMMIT;
