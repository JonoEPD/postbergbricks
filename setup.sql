CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS dataset;
CREATE TABLE dataset (
    label varchar(10)
    , identifier int
    , val float
    , str varchar(10)
    , data_id text
);
PARTITION BY LIST(data_id);
CREATE INDEX dataset_label_idx ON dataset USING gin (label gin_trgm_ops);
CREATE INDEX dataset_identifier_idx ON dataset(identifier);

DROP TABLE IF EXISTS dataset_nopartition;
CREATE TABLE dataset_nopartition (
    label varchar(10)
    , identifier int
    , val float
    , str varchar(10)
    , data_id text
);
CREATE INDEX dataset_nopartition_data_id_idx ON dataset_nopartition(data_id);
CREATE INDEX dataset_nopartition_label_idx ON dataset_nopartition USING gin (label gin_trgm_ops);
CREATE INDEX dataset_nopartition_identifier_idx ON dataset_nopartition(identifier);

DO $$
DECLARE 
    dataTable text;
    countData integer;
BEGIN
FOR dataTable IN SELECT to_char(dt, 'YYYYMMDD')::integer FROM generate_series(TIMESTAMP '2024-01-01', TIMESTAMP '2024-06-01', INTERVAL '1 day') dt
    LOOP
        RAISE NOTICE 'creating partition %', dataTable;
        EXECUTE 'CREATE TABLE IF NOT EXISTS dataset_' || dataTable || ' PARTITION OF dataset FOR VALUES IN ('|| dataTable || ')';
    END LOOP;
END; $$;

DO $$
DECLARE 
    dataTable text;
    countData integer;
BEGIN
FOR dataTable IN SELECT to_char(dt, 'YYYYMMDD')::integer FROM generate_series(TIMESTAMP '2024-01-01', TIMESTAMP '2024-06-01', INTERVAL '1 day') dt
    LOOP
        RAISE NOTICE 'inserting data into partition %', dataTable;
        EXECUTE '
INSERT INTO dataset
SELECT 
label::text, 
identifier,
random() * 10,
substr(md5(random()::text), 1,10),' || dataTable || 
' AS data_id
FROM (
    SELECT 
        substr(md5(random()::text), 1, 5) FROM generate_series(1,1000) -- generate 100 random labels
    ) AS label,
    generate_series(1,10000) AS identifier
';
    END LOOP;
END; $$;
-- 13mins 80s to insert 153m rows into 153 partitions

-- timer: 
INSERT INTO dataset_nopartition
SELECT label, identifier, val, str, data_id 
FROM dataset;


