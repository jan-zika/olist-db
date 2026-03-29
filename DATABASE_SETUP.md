# Database Setup

## Data Source

The dataset used in this project is the [Olist Brazilian E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), originally distributed as a collection of CSV files. For this project it was consolidated into a single relational database and loaded into Azure SQL.

## Schema Design

The original CSV files have no primary keys, foreign keys, or indexes. During the database setup process, the schema was enhanced with:

- **Primary keys** on all main entity tables (customers, sellers, products, orders, etc.)
- **Foreign keys** enforcing referential integrity between related tables
- **Indexes** on frequently joined and filtered columns (zip codes, foreign key columns, order status)
- **Appropriate SQL Server data types** (NVARCHAR, INT, FLOAT, DECIMAL for coordinates)

The `geolocation` table has no primary key by design — Brazilian zip codes cover areas, not points, so the dataset intentionally includes multiple coordinate samples per zip code. A non-unique index on `geolocation_zip_code_prefix` is sufficient for lookups.

The `order_reviews` table has duplicate `review_id` values in the source data (some customers re-reviewed the same order). A surrogate key `review_row_id INT IDENTITY` was added as the primary key to uniquely identify each row without removing any data.

Geolocation coordinates are stored as `DECIMAL(22,19)` to preserve the full precision of the source data.

## Load Process

The database was loaded into Azure SQL using the following steps:

### 1. SQLite to SQL Server Conversion
The source data was available as a SQLite database file. A conversion process transformed the SQLite dump into SQL Server-compatible T-SQL scripts, handling:
- Data type mapping (SQLite `TEXT`/`REAL`/`INTEGER` → SQL Server `NVARCHAR`/`FLOAT`/`INT`)
- Scientific notation in floating-point values (geolocation coordinates)
- Embedded newlines in text fields (customer review comments)
- Correct insert ordering to satisfy foreign key constraints

### 2. Local SQL Server Load
The T-SQL scripts were executed against a local SQL Server instance using SQL Server Management Studio (SSMS). The data was loaded table by table to manage memory usage, with the largest table (geolocation, ~1M rows) loaded separately.

### 3. BACPAC Export
Once the local database was verified, it was exported as a BACPAC file using SSMS:
> Right-click database → Tasks → Export Data-tier Application

A BACPAC is Azure SQL's native portable format — a ZIP archive containing the schema and all data.

### 4. Azure SQL Import
The BACPAC was uploaded to Azure Blob Storage, then imported into Azure SQL via the Azure Portal:
> SQL Server → Import Database → select BACPAC from storage

### 5. Access Control
A read-only SQL login (`olist_reader`) was created with `SELECT` permissions on the `dbo` schema, allowing team members to query the data without risk of modification.

## Connection Details

| Setting | Value |
|---|---|
| Server | cap2761c-zika-305.database.windows.net |
| Database | olist-db |
| Username | olist_reader |
| Auth | SQL Server authentication |

Password is shared with team members directly and stored in a local `.env` file (not committed to this repository).
