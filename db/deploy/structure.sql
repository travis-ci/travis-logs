-- Deploy travis-logs:structure to pg

BEGIN;

  SET client_min_messages = WARNING;

  CREATE TABLE log_parts (
    id bigint NOT NULL,
    log_id integer NOT NULL,
    content text,
    number integer,
    final boolean,
    created_at timestamp without time zone
  );

  CREATE SEQUENCE log_parts_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

  ALTER SEQUENCE log_parts_id_seq OWNED BY log_parts.id;

  CREATE TABLE logs (
    id integer NOT NULL,
    job_id integer,
    content text,
    removed_by integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    aggregated_at timestamp without time zone,
    archived_at timestamp without time zone,
    purged_at timestamp without time zone,
    removed_at timestamp without time zone,
    archiving boolean,
    archive_verified boolean
  );

  CREATE SEQUENCE logs_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

  ALTER SEQUENCE logs_id_seq OWNED BY logs.id;

  ALTER TABLE ONLY log_parts
  ALTER COLUMN id
  SET DEFAULT nextval('log_parts_id_seq'::regclass);

  ALTER TABLE ONLY logs
  ALTER COLUMN id
  SET DEFAULT nextval('logs_id_seq'::regclass);

  ALTER TABLE ONLY log_parts
  ADD CONSTRAINT log_parts_pkey PRIMARY KEY (id);

  ALTER TABLE ONLY logs
  ADD CONSTRAINT logs_pkey PRIMARY KEY (id);

  CREATE INDEX index_log_parts_on_created_at
  ON log_parts
  USING btree (created_at);

  CREATE INDEX index_log_parts_on_log_id_and_number
  ON log_parts
  USING btree (log_id, number);

  CREATE INDEX index_logs_on_archive_verified
  ON logs
  USING btree (archive_verified);

  CREATE INDEX index_logs_on_archived_at
  ON logs
  USING btree (archived_at);

  CREATE INDEX index_logs_on_job_id
  ON logs
  USING btree (job_id);

COMMIT;
