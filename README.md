# postbergbricks
Playing with postgres+iceberg interop and comparing partitioning strategies.

## setup

```
docker-compose up -d
docker exec -it postgres psql -U myuser -d mydb
```
Then run the scripts adhoc.

# Testing Partitioning

Partitiong strategy is to create a unique partition for each data_id.

Use case is: all data for a data_id is inserted into the table at once, then never written again.

### Summary

Using i9-10920X CPU ()

Great performance for:
- writing new data_id to dataset (3200ms/1m rows)
- retrieving new data_id after write (700ms/1m rows)
- queries filtered by label
- queries filtered by identifier

All admin operations are <100ms, usually ~10ms.

### Specific tests

| test | timer (partitioned) | timer(not partitioned) | description |
| ---- | ----  | --- | ----------  |
| write all | 8mins | |insert 153m rows (into 153 partitions) |
| create new partition | 9ms || create a partition for a new data_id
| insert all data for data_id |  3200ms |  | insert 1m rows into partition for a new data_id
| COUNT(*) | 7s | 2.5s |count all 153m rows in table |
| COUNT(*) partition from main table | **53ms** | 3.4s | select count(*) from dataset WHERE data_id=xyz
| COUNT(*) partition directly | 34ms || select count(*) from dataset_xyz
| select where label -missing | 10ms |2838ms | select all data for a label that does not exist |
| select where label -exact match | 32ms | 2953ms| text lookup |
| select where label LIKE 'abc%' | **56ms** | 14529ms | left-rooted text search |
| select where label LIKE '%a%c%' | 270ms | 4461ms | complex text search |
| retrieval | 700ms | 4100ms | SELECT * and write 1m rows from a specific partition |
| detatch partition | 3ms || prune a partition from the main table |
| attach partition | 122ms || add an existing table as partition of the main table |

*impacted by extra indexes on the no-partitioned dataset table