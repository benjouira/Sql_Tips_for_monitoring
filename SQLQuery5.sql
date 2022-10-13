

--without primary key
SELECT [table] = s.name + N'.' + t.name 
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE NOT EXISTS
  (
    SELECT 1 FROM sys.key_constraints AS k
      WHERE k.[type] = N'PK'
      AND k.parent_object_id = t.[object_id]
  );

  --without clustered index
  SELECT [table] = s.name + N'.' + t.name 
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE NOT EXISTS
  (
    SELECT 1 FROM sys.indexes AS i
      WHERE i.[object_id] = t.[object_id]
      AND i.index_id = 1
  );

  --This can help identify heaps that need to be rebuilt to reclaim space (or simply heaps that maybe shouldn't be heaps at all), with a filter for a minimum amount of rows in the table.
  DECLARE @percentage DECIMAL(5,2), @min_row_count INT;
SELECT @percentage = 10, @min_row_count = 1000;

;WITH x([table], [fwd_%]) AS 
(
  SELECT s.name + N'.' + t.name, CONVERT(DECIMAL(5,2), 100 * CONVERT(DECIMAL(18,2), 
      SUM(ps.forwarded_record_count)) / NULLIF(SUM(ps.record_count),0))
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
    ON t.[schema_id] = s.[schema_id]
    INNER JOIN sys.indexes AS i
    ON t.[object_id] = i.[object_id]
    CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(), 
      t.[object_id], i.index_id, NULL, N'DETAILED') AS ps
    WHERE i.index_id = 0
    AND EXISTS
    (
      SELECT 1 FROM sys.partitions AS p
        WHERE p.[object_id] = t.[object_id]
        AND p.index_id = 0 -- heap
        GROUP BY p.[object_id]
        HAVING SUM(p.[rows]) >= @min_row_count
    )
    AND ps.record_count >= @min_row_count
    AND ps.forwarded_record_count IS NOT NULL
    GROUP BY s.name, t.name
)
SELECT [table], [fwd_%]
  FROM x
  WHERE [fwd_%] > @percentage
  ORDER BY [fwd_%] DESC;

  --SQL Server Tables without an Identity Column
  SELECT [table] = s.name + N'.' + t.name 
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE NOT EXISTS
  (
    SELECT 1 FROM sys.identity_columns AS i
      WHERE i.[object_id] = t.[object_id]
  );
  --SQL Server Tables with at Least two Triggers
  DECLARE @min_count INT;
SET @min_count = 2;

SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.triggers AS tr
      WHERE tr.parent_id = t.[object_id]
      GROUP BY tr.parent_id
      HAVING COUNT(*) >= @min_count
  );
  --SQL Server Tables with at least one Disabled Trigger
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS 
  (
    SELECT 1 FROM sys.triggers AS tr
      WHERE tr.parent_id = t.[object_id]
      AND tr.is_disabled = 1
  );
  --SQL Server Tables with INSTEAD OF Triggers
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS 
  (
    SELECT 1 FROM sys.triggers AS tr
      WHERE tr.parent_id = t.[object_id]
      AND tr.is_instead_of_trigger = 1
  );
  --SQL Server Tables with More Than Twenty Columns
  DECLARE @threshold INT;
SET @threshold = 20;

;WITH c([object_id], [column count]) AS
(
  SELECT [object_id], COUNT(*)
    FROM sys.columns
    GROUP BY [object_id]
    HAVING COUNT(*) > @threshold
)
SELECT [table] = s.name + N'.' + t.name,
    c.[column count]
  FROM c
  INNER JOIN sys.tables AS t
  ON c.[object_id] = t.[object_id]
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  ORDER BY c.[column count] DESC;
  --SQL Server Tables that have at least one Column Name Matching N'%pattern%'
  DECLARE @pattern NVARCHAR(128);
SET @pattern = N'%pattern%';

SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.columns AS c
      WHERE c.[object_id] = t.[object_id]
      AND LOWER(c.name) LIKE LOWER(@pattern)
      -- LOWER() due to potential case sensitivity
  );
  --SQL Server Tables with at least one XML Column
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.columns AS c
      WHERE c.[object_id] = t.[object_id]
      AND c.system_type_id = 241 -- 241 = xml
  );
  --SQL Server Tables with at least one LOB (MAX) Column
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.columns AS c
      WHERE c.[object_id] = t.[object_id]
      AND c.max_length = -1
      AND c.system_type_id IN 
      (
        165, -- varbinary
        167, -- varchar
        231  -- nvarchar
      )
  );
  --SQL Server Tables with at least one TEXT / NTEXT / IMAGE Column
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.columns AS c
      WHERE c.[object_id] = t.[object_id]
      AND c.system_type_id IN 
      (
        34, -- image
        35, -- text
        99  -- ntext
      )
  );
  --SQL Server Tables with Foreign Keys Referencing Other Tables
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.foreign_keys AS fk
      WHERE fk.parent_object_id = t.[object_id]
  );
  --SQL Server Tables with Foreign Keys that Reference a Specific Table
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.foreign_keys AS fk
      INNER JOIN sys.tables AS pt -- "parent table"
      ON fk.referenced_object_id = pt.[object_id]
      INNER JOIN sys.schemas AS ps
      ON pt.[schema_id] = ps.[schema_id]
      WHERE fk.parent_object_id = t.[object_id]
      AND ps.name = N'schema_name'
      AND pt.name = N'table_name'
  );
  --SQL Server Tables Referenced by Foreign Keys
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.foreign_keys AS fk
      WHERE fk.referenced_object_id = t.[object_id]
  );
  --SQL Server Tables with Foreign Keys that Cascade
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.foreign_keys AS fk
      WHERE fk.parent_object_id = t.[object_id]
      AND (fk.delete_referential_action = 1 
       OR  fk.update_referential_action = 1)
  );
  --SQL Server Tables with Disabled Foreign Keys
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.foreign_keys AS fk
      WHERE fk.parent_object_id = t.[object_id]
      AND fk.is_disabled = 1
  );
  --SQL Server Tables with Self-Referencing Foreign Keys
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.foreign_keys AS fk
      WHERE fk.parent_object_id = t.[object_id]
      AND fk.referenced_object_id = t.[object_id]
  );

  --SQL Server Tables with Disabled Indexes
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.indexes AS i
      WHERE i.[object_id] = t.[object_id]
      AND i.is_disabled = 1
  );
  --SQL Server Tables with More Than Five Indexes
DECLARE @threshold INT;
SET @threshold = 5;

SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.indexes AS i
      WHERE i.[object_id] = t.[object_id]
      GROUP BY i.[object_id]
      HAVING COUNT(*) > @threshold
  );
  /*
  SQL Server Tables with More Than One Index with the Same Leading Key Column
These may very well be at least partially redundant indexes - we are also sure to check that the leading key column is defined in the same order, since there are use cases for one index ascending and another index descending. NOTE: We're going to stick to heaps, clustered indexes and non-clustered indexes for now, ignoring XML indexes, as well as spatial, columnstore and hash indexes.
  */
  SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1
      FROM sys.indexes AS i
      INNER JOIN sys.index_columns AS ic1
      ON i.[object_id] = ic1.[object_id]
      AND i.index_id = ic1.index_id
      INNER JOIN sys.index_columns AS ic2
      ON i.[object_id] = ic2.[object_id]
      AND ic1.index_column_id = ic2.index_column_id
      AND ic1.column_id = ic2.column_id
      AND ic1.is_descending_key = ic2.is_descending_key
      AND ic1.index_id <> ic2.index_id
      WHERE i.[type] IN (0,1,2) -- heap, cix, ncix
      AND ic1.index_column_id = 1
      AND ic2.index_column_id = 1
      AND i.[object_id] = t.[object_id]
      GROUP BY i.[object_id]
      HAVING COUNT(*) > 1
  );
  --SQL Server Tables with More (or Less) Than X Rows
--A lot of people will create a loop and perform a heavy SELECT COUNT(*) against every table. Or they'll loop through and insert the results of sp_spaceused into a #temp table, then filter the results. It is much less intrusive to just check the catalog view sys.partitions:

DECLARE @threshold INT;
SET @threshold = 1;

SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.partitions AS p
      WHERE p.[object_id] = t.[object_id]
        AND p.index_id IN (0,1)
      GROUP BY p.[object_id]
      HAVING SUM(p.[rows]) < @threshold
  );

--All SQL Server Tables in a Schema
DECLARE @schema SYSNAME;
SET @schema = N'dbo';

SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE s.name = @schema;

  --SQL Server Tables Referenced Directly by at least one View
SELECT [table] = s.name + N'.' + t.name
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE EXISTS
  (
    SELECT 1 FROM sys.tables AS st
      INNER JOIN sys.schemas AS ss
      ON st.[schema_id] = ss.[schema_id]
      CROSS APPLY sys.dm_sql_referencing_entities
        (QUOTENAME(ss.name) + N'.' + QUOTENAME(st.name), 
         N'OBJECT') AS r
      INNER JOIN sys.views AS v
      ON v.[object_id] = r.referencing_id
      INNER JOIN sys.schemas AS vs
      ON v.[schema_id] = vs.[schema_id]
      WHERE st.[object_id] = t.[object_id]
  );
  --