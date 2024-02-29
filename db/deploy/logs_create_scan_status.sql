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
COMMIT;
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_logs_on_scan_status_and_id_desc ON public.logs USING btree (scan_status, id DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_logs_on_scan_status_and_scan_status_updated_at ON public.logs USING btree (scan_status, scan_status_updated_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_logs_on_scan_status_and_created_at_desc ON public.logs USING btree (scan_status, created_at DESC);