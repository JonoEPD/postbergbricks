-- retrieval reasonably fast filtering by id. faster on direct table
SELECT COUNT(*) FROM dataset WHERE data_id='20240122'; -- timing 53ms
SELECT COUNT(*) FROM dataset_20240122; -- timing 34ms, bit faster

-- lookup labels across partitions. none of these table scan!
-- table scan would be 4.6s
SELECT COUNT(*) FROM dataset WHERE label LIKE '(abcd%'; -- 20k: timing 1400ms for left-rooted match
SELECT COUNT(*) FROM dataset WHERE label LIKE '(abcdefg%'; -- 0: timing 1800ms for no match
SELECT * FROM dataset WHERE label =  '(abc34)' AND data_id = '20240403'; -- 20ms: direct lookup fast


-- test retrieval speed
DROP TABLE IF EXISTS test_write_speed;
CREATE TABLE test_write_speed AS (SELECT* FROM dataset WHERE data_id='20240423'); -- 700ms
