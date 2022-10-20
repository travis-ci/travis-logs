-- Deploy travis-logs:create_scan_results_table to pg

BEGIN;

  SET client_min_messages = WARNING;

  CREATE TABLE scan_results (
    id bigint NOT NULL,
    log_id bigint NOT NULL,
    job_id bigint NOT NULL,
    repository_id bigint NOT NULL,
    owner_id integer NOT NULL,
    owner_type character varying NOT NULL,
    created_at timestamp without time zone,
    content jsonb NOT NULL,
    issues_found integer NOT NULL,
    archived boolean,
    purged_at timestamp without time zone,
    token character varying NOT NULL,
    token_created_at timestamp without time zone
  );

  CREATE SEQUENCE scan_results_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

  ALTER SEQUENCE scan_results_id_seq OWNED BY scan_results.id;

  ALTER TABLE ONLY scan_results
  ALTER COLUMN id
  SET DEFAULT nextval('scan_results_id_seq'::regclass);
  
  ALTER TABLE ONLY scan_results
  ADD CONSTRAINT scan_results_pkey PRIMARY KEY (id);

  CREATE INDEX index_scan_results_on_repository_id
  ON scan_results
  USING btree (repository_id);

COMMIT;
