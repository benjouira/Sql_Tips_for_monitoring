insert into AUDIT_Rabii3..WithoutPrimaryKey


SELECT  DB_NAME(db_id()) as nom, [table] = s.name + N'.' + t.name 
  FROM sys.tables AS t
  INNER JOIN sys.schemas AS s
  ON t.[schema_id] = s.[schema_id]
  WHERE   NOT EXISTS
  (
    SELECT 1 FROM sys.key_constraints AS k
      WHERE k.[type] = N'PK'
      AND k.parent_object_id = t.[object_id]
  );
