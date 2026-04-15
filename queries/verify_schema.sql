-- ============================================================
-- Schema + data profile verification
-- Run against olist-db
-- ============================================================

SET NOCOUNT ON;

DECLARE @sql       NVARCHAR(MAX);
DECLARE @table     NVARCHAR(128);
DECLARE @col       NVARCHAR(128);
DECLARE @type      NVARCHAR(128);
DECLARE @full_type NVARCHAR(60);
DECLARE @ft_lit    NVARCHAR(62);
DECLARE @t_lit     NVARCHAR(130);
DECLARE @c_lit     NVARCHAR(130);

IF OBJECT_ID('tempdb..#profile') IS NOT NULL DROP TABLE #profile;
CREATE TABLE #profile (
    table_name     NVARCHAR(128),
    column_name    NVARCHAR(128),
    full_type      NVARCHAR(60),
    nullable       BIT,
    null_count     INT,
    distinct_count INT,
    min_val        NVARCHAR(200),
    max_val        NVARCHAR(200),
    sample_1       NVARCHAR(200),
    sample_2       NVARCHAR(200),
    sample_3       NVARCHAR(200),
    extra_stat     NVARCHAR(200),
    sanity_check   NVARCHAR(400)  NULL
);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        t.name,
        c.name,
        CASE
            WHEN tp.name IN ('decimal','numeric')
                THEN tp.name + '(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
            WHEN tp.name IN ('nvarchar','varchar','char','nchar')
                THEN tp.name + '(' + CASE WHEN c.max_length = -1 THEN 'MAX'
                                          ELSE CAST(c.max_length / 2 AS VARCHAR) END + ')'
            ELSE tp.name
        END,
        tp.name
    FROM sys.tables t
    JOIN sys.columns c ON c.object_id = t.object_id
    JOIN sys.types tp ON tp.user_type_id = c.user_type_id
    WHERE t.schema_id = SCHEMA_ID('dbo')
    ORDER BY t.name, c.column_id;

OPEN cur;
FETCH NEXT FROM cur INTO @table, @col, @full_type, @type;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ft_lit = REPLACE(@full_type, '''', '''''');
    SET @t_lit  = REPLACE(@table,     '''', '''''');
    SET @c_lit  = REPLACE(@col,       '''', '''''');

    IF @type IN ('int','smallint','tinyint','bigint','float','real','decimal','numeric','money','smallmoney')
    BEGIN
        SET @sql = N'
        INSERT INTO #profile
        SELECT N''' + @t_lit + ''', N''' + @c_lit + ''', N''' + @ft_lit + ''',
            (SELECT is_nullable FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id
             WHERE t.name=N''' + @t_lit + ''' AND c.name=N''' + @c_lit + '''),
            SUM(CASE WHEN ' + QUOTENAME(@col) + ' IS NULL THEN 1 ELSE 0 END),
            COUNT(DISTINCT ' + QUOTENAME(@col) + '),
            CAST(MIN(' + QUOTENAME(@col) + ') AS NVARCHAR(200)),
            CAST(MAX(' + QUOTENAME(@col) + ') AS NVARCHAR(200)),
            CAST(MIN(CASE WHEN rn=1 THEN ' + QUOTENAME(@col) + ' END) AS NVARCHAR(200)),
            CAST(MIN(CASE WHEN rn=2 THEN ' + QUOTENAME(@col) + ' END) AS NVARCHAR(200)),
            CAST(MIN(CASE WHEN rn=3 THEN ' + QUOTENAME(@col) + ' END) AS NVARCHAR(200)),
            N''avg='' + CAST(CAST(AVG(CAST(' + QUOTENAME(@col) + ' AS FLOAT)) AS DECIMAL(18,4)) AS NVARCHAR(100)),
            NULL
        FROM (SELECT ' + QUOTENAME(@col) + ', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
              FROM ' + QUOTENAME(@table) + ' WHERE ' + QUOTENAME(@col) + ' IS NOT NULL) x;';
    END
    ELSE IF @type IN ('datetime','datetime2','date','datetimeoffset','smalldatetime','time')
    BEGIN
        SET @sql = N'
        INSERT INTO #profile
        SELECT N''' + @t_lit + ''', N''' + @c_lit + ''', N''' + @ft_lit + ''',
            (SELECT is_nullable FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id
             WHERE t.name=N''' + @t_lit + ''' AND c.name=N''' + @c_lit + '''),
            SUM(CASE WHEN ' + QUOTENAME(@col) + ' IS NULL THEN 1 ELSE 0 END),
            COUNT(DISTINCT ' + QUOTENAME(@col) + '),
            CONVERT(NVARCHAR(30), MIN(' + QUOTENAME(@col) + '), 120),
            CONVERT(NVARCHAR(30), MAX(' + QUOTENAME(@col) + '), 120),
            CONVERT(NVARCHAR(30), MIN(CASE WHEN rn=1 THEN ' + QUOTENAME(@col) + ' END), 120),
            CONVERT(NVARCHAR(30), MIN(CASE WHEN rn=2 THEN ' + QUOTENAME(@col) + ' END), 120),
            CONVERT(NVARCHAR(30), MIN(CASE WHEN rn=3 THEN ' + QUOTENAME(@col) + ' END), 120),
            N''range_days='' + CAST(DATEDIFF(DAY, MIN(' + QUOTENAME(@col) + '), MAX(' + QUOTENAME(@col) + ')) AS NVARCHAR(20)),
            NULL
        FROM (SELECT ' + QUOTENAME(@col) + ', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
              FROM ' + QUOTENAME(@table) + ' WHERE ' + QUOTENAME(@col) + ' IS NOT NULL) x;';
    END
    ELSE
    BEGIN
        SET @sql = N'
        INSERT INTO #profile
        SELECT N''' + @t_lit + ''', N''' + @c_lit + ''', N''' + @ft_lit + ''',
            (SELECT is_nullable FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id
             WHERE t.name=N''' + @t_lit + ''' AND c.name=N''' + @c_lit + '''),
            SUM(CASE WHEN ' + QUOTENAME(@col) + ' IS NULL THEN 1 ELSE 0 END),
            COUNT(DISTINCT ' + QUOTENAME(@col) + '),
            LEFT(CAST(MIN(' + QUOTENAME(@col) + ') AS NVARCHAR(MAX)), 100),
            LEFT(CAST(MAX(' + QUOTENAME(@col) + ') AS NVARCHAR(MAX)), 100),
            LEFT(MIN(CASE WHEN rn=1 THEN CAST(' + QUOTENAME(@col) + ' AS NVARCHAR(MAX)) END), 100),
            LEFT(MIN(CASE WHEN rn=2 THEN CAST(' + QUOTENAME(@col) + ' AS NVARCHAR(MAX)) END), 100),
            LEFT(MIN(CASE WHEN rn=3 THEN CAST(' + QUOTENAME(@col) + ' AS NVARCHAR(MAX)) END), 100),
            N''max_len='' + CAST(MAX(LEN(CAST(' + QUOTENAME(@col) + ' AS NVARCHAR(MAX)))) AS NVARCHAR(20)),
            NULL
        FROM (SELECT ' + QUOTENAME(@col) + ', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
              FROM ' + QUOTENAME(@table) + ' WHERE ' + QUOTENAME(@col) + ' IS NOT NULL) x;';
    END

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        INSERT INTO #profile VALUES (@table, @col, @full_type, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, N'ERROR: ' + ERROR_MESSAGE(), 'ERROR');
    END CATCH

    FETCH NEXT FROM cur INTO @table, @col, @full_type, @type;
END

CLOSE cur;
DEALLOCATE cur;

-- ============================================================
-- Sanity checks — set-based pass over collected profile data
-- ============================================================

-- Default: OK
UPDATE #profile SET sanity_check = 'OK';

-- nvarchar(n): observed max_len must not exceed declared n
UPDATE #profile
SET sanity_check = 'WARN: max_len ' + REPLACE(extra_stat, 'max_len=', '')
                   + ' exceeds declared ' + full_type
WHERE full_type LIKE 'nvarchar([0-9]%)'
  AND TRY_CAST(REPLACE(REPLACE(full_type, 'nvarchar(', ''), ')', '') AS INT) IS NOT NULL
  AND TRY_CAST(REPLACE(extra_stat, 'max_len=', '') AS INT) IS NOT NULL
  AND TRY_CAST(REPLACE(extra_stat, 'max_len=', '') AS INT)
      > TRY_CAST(REPLACE(REPLACE(full_type, 'nvarchar(', ''), ')', '') AS INT);

-- varchar(n): same
UPDATE #profile
SET sanity_check = 'WARN: max_len ' + REPLACE(extra_stat, 'max_len=', '')
                   + ' exceeds declared ' + full_type
WHERE full_type LIKE 'varchar([0-9]%)'
  AND TRY_CAST(REPLACE(REPLACE(full_type, 'varchar(', ''), ')', '') AS INT) IS NOT NULL
  AND TRY_CAST(REPLACE(extra_stat, 'max_len=', '') AS INT) IS NOT NULL
  AND TRY_CAST(REPLACE(extra_stat, 'max_len=', '') AS INT)
      > TRY_CAST(REPLACE(REPLACE(full_type, 'varchar(', ''), ')', '') AS INT);

-- int: must fit in [-2147483648, 2147483647]
UPDATE #profile
SET sanity_check = 'WARN: value out of INT range (min=' + ISNULL(min_val,'null')
                   + ', max=' + ISNULL(max_val,'null') + ')'
WHERE full_type = 'int'
  AND (TRY_CAST(min_val AS BIGINT) < -2147483648
    OR TRY_CAST(max_val AS BIGINT) >  2147483647);

-- smallint: [-32768, 32767]
UPDATE #profile
SET sanity_check = 'WARN: value out of SMALLINT range (min=' + ISNULL(min_val,'null')
                   + ', max=' + ISNULL(max_val,'null') + ')'
WHERE full_type = 'smallint'
  AND (TRY_CAST(min_val AS INT) < -32768
    OR TRY_CAST(max_val AS INT) >  32767);

-- tinyint: [0, 255]
UPDATE #profile
SET sanity_check = 'WARN: value out of TINYINT range (min=' + ISNULL(min_val,'null')
                   + ', max=' + ISNULL(max_val,'null') + ')'
WHERE full_type = 'tinyint'
  AND (TRY_CAST(min_val AS INT) < 0
    OR TRY_CAST(max_val AS INT) > 255);

-- decimal(p,s): check scale — fractional digits in max_val must not exceed s
-- Extract s from full_type e.g. 'decimal(10,2)' -> '2'
UPDATE #profile
SET sanity_check = 'WARN: fractional digits in max_val (' + max_val
                   + ') may exceed scale in ' + full_type
WHERE full_type LIKE 'decimal(%,%)'
  AND CHARINDEX('.', max_val) > 0
  AND LEN(SUBSTRING(max_val, CHARINDEX('.', max_val) + 1, 20))
      > TRY_CAST(
            SUBSTRING(full_type,
                CHARINDEX(',', full_type) + 1,
                CHARINDEX(')', full_type) - CHARINDEX(',', full_type) - 1)
        AS INT);

-- date / datetime2: flag if outside expected dataset range (2000–2030)
UPDATE #profile
SET sanity_check = 'WARN: date out of expected range 2000-2030 (min=' + ISNULL(min_val,'null')
                   + ', max=' + ISNULL(max_val,'null') + ')'
WHERE full_type IN ('date', 'datetime2')
  AND (TRY_CAST(min_val AS DATETIME2) < '2000-01-01'
    OR TRY_CAST(max_val AS DATETIME2) > '2030-01-01');

-- preserve ERROR rows
UPDATE #profile
SET sanity_check = extra_stat
WHERE extra_stat LIKE 'ERROR:%';

-- ============================================================
-- Final output — warnings first, then alphabetical
-- ============================================================
SELECT
    table_name,
    column_name,
    full_type,
    nullable,
    null_count,
    distinct_count,
    min_val,
    max_val,
    sample_1,
    sample_2,
    sample_3,
    extra_stat,
    sanity_check
FROM #profile
ORDER BY
    CASE WHEN sanity_check LIKE 'WARN%' OR sanity_check LIKE 'ERROR%' THEN 0 ELSE 1 END,
    table_name,
    column_name;

DROP TABLE #profile;
