# postbergbricks
Playing with postgres+iceberg interop and comparing partitioning strategies.

# Testing Partitioning

Partitiong strategy is to create a unique partition for each data_id.

Use case is: all data for a data_id is inserted into the table at once, then never written again.

### Summary

Great performance for:
- writing new data_id to dataset (3200ms/1m rows)
- retrieving new data_id after write (700ms/1m rows)
- queries filtered by label
- queries filtered by identifier

All admin operations are <100ms, usually ~10ms.

### Specific tests

| test | timer | description |
| ---- | ----  | ----------  |
| write all | 8mins |insert 153m rows into 153 partitions of indexed table |
| create new partition | 9ms | create a partition for a new data_id
| insert into new partition | 3200ms | insert 1m rows into partition for a new data_id
| COUNT(*) | 7s | count all 153m rows in table |
| COUNT(*) partition from main table | 53ms | select count(*) from dataset WHERE data_id=xyz
| COUNT(*) partition directly | 34ms | select count(*) from dataset_xyz
| select where label -missing | 10ms | select all data for a label that does not exist |
| select where label -exact match | 32ms | text lookup |
| select where label LIKE 'abc%' | 56ms | left-rooted text search |
| select where label LIKE '%a%c%' | 270ms | complex text search |
| retrieval | 700ms | SELECT * and write 1m rows from a specific partition |
| detatch partition | 3ms | prune a partition from the main table |
| attach partition | 122ms | add an existing table as partition of the main table |
