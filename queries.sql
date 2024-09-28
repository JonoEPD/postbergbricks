CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS dataset;
CREATE TABLE dataset (
    label varchar(10)
    , val float
    , str varchar(10)
    , data_id text
)
PARTITION BY LIST(data_id);
CREATE INDEX dataset_label_idx ON dataset USING gin (label gin_trgm_ops);

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
random() * 10,
substr(md5(random()::text), 1,10),' || dataTable || 
' AS data_id
FROM (
    SELECT 
        substr(md5(random()::text), 1, 5) FROM generate_series(1,100) -- generate 100 random labels
    ) AS label,
    generate_series(1,10000) AS identifier
';
    END LOOP;
END; $$;
-- 13mins 80s to insert 153m rows into 153 partitions


-- detatch partition - all commands run in few ms
-- DROP TABLE after detatching to save memory.
SELECT COUNT(*) FROM dataset; -- 153m, timing 4s
ALTER TABLE dataset DETACH PARTITION dataset_20240129;
SELECT COUNT(*) FROM dataset_20240129; -- 1m, timing 10ms
SELECT COUNT(*) FROM dataset;  -- 152m

-- reattach partition
ALTER TABLE dataset ATTACH PARTITION dataset_20240129 FOR VALUES IN ('20240129');
SELECT COUNT(*) FROM dataset; -- 15.3m like before

-- retrieval reasonably fast filtering by id. faster on direct table
SELECT COUNT(*) FROM dataset WHERE data_id='20240122'; -- timing 53ms
SELECT COUNT(*) FROM dataset_20240122; -- timing 34ms, bit faster

-- lookup labels across partitions. none of these table scan!
-- table scan would be 4.6s
SELECT COUNT(*) FROM dataset WHERE label LIKE '(abc%'; -- 10k: timing 56s for left-rooted match
SELECT COUNT(*) FROM dataset WHERE label LIKE '%abc%'; -- 100k: timing 300ms for both-sides match
SELECT COUNT(*) FROM dataset WHERE label LIKE '%(%bcd%'; -- 80k: timing 270ms for complex search
SELECT label, COUNT(*) FROM dataset WHERE label LIKE '%(%bcd%' GROUP BY label; -- 80k: timing still 270ms for a groupby