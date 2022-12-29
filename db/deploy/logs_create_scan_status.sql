-- Deploy travis-logs:logs_create_scan_status to pg
-- requires: partman_remove_constraint

BEGIN;

  SET client_min_messages = WARNING;

  ALTER TABLE logs
  ADD COLUMN scan_status character varying,
  ADD COLUMN scan_status_updated_at timestamp without time zone,
  ADD COLUMN censored boolean,
  ADD COLUMN scan_queued_at timestamp without time zone,
  ADD COLUMN scan_started_at timestamp without time zone,
  ADD COLUMN scan_processing_at timestamp without time zone,
  ADD COLUMN scan_finalizing_at timestamp without time zone,
  ADD COLUMN scan_ended_at timestamp without time zone;

  CREATE INDEX IF NOT EXISTS index_logs_on_scan_status_order_by_newest ON public.logs USING btree (scan_status, id DESC);
  CREATE INDEX IF NOT EXISTS index_logs_on_scan_status_and_scan_status_updated_at ON public.logs USING btree (scan_status, scan_status_updated_at);
  -- CREATE INDEX IF NOT EXISTS index_logs_on_scan_status_and_scan_status_updated_at_where_running ON public.logs USING btree (scan_status, scan_status_updated_at) WHERE ((scan_status)::text = ANY ((ARRAY['started'::character varying, 'processing'::character varying, 'finalizing'::character varying])::text[]));
  CREATE INDEX IF NOT EXISTS index_logs_on_scan_queued_at ON public.logs USING btree (scan_queued_at);
  CREATE INDEX IF NOT EXISTS index_logs_on_scan_started_at ON public.logs USING btree (scan_started_at);
  CREATE INDEX IF NOT EXISTS index_logs_on_scan_processing_at ON public.logs USING btree (scan_processing_at);
  CREATE INDEX IF NOT EXISTS index_logs_on_scan_finalizing_at ON public.logs USING btree (scan_finalizing_at);
  CREATE INDEX IF NOT EXISTS index_logs_on_scan_ended_at ON public.logs USING btree (scan_ended_at);

COMMIT;
