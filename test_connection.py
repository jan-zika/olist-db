"""
Database connection helper for the Olist Azure SQL database.

Usage:
    from db import get_connection

    conn = get_connection()
    df = pd.read_sql("SELECT * FROM dbo.orders LIMIT 10", conn)
    conn.close()

Requirements:
    pip install pyodbc python-dotenv

ODBC Driver:
    Download "ODBC Driver 18 for SQL Server" from Microsoft if not installed:
    https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server
"""

import os
import pyodbc
from dotenv import load_dotenv

load_dotenv()


def get_connection():
    server   = os.getenv("AZURE_SQL_SERVER")
    database = os.getenv("AZURE_SQL_DATABASE")
    user     = os.getenv("AZURE_SQL_USER")
    password = os.getenv("AZURE_SQL_PASSWORD")

    missing = [k for k, v in {
        "AZURE_SQL_SERVER":   server,
        "AZURE_SQL_DATABASE": database,
        "AZURE_SQL_USER":     user,
        "AZURE_SQL_PASSWORD": password,
    }.items() if not v]

    if missing:
        raise EnvironmentError(
            f"Missing environment variables: {', '.join(missing)}\n"
            "Copy .env.example to .env and fill in the values."
        )

    return pyodbc.connect(
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={password};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30;"
    )


if __name__ == "__main__":
    print("Testing connection...")
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM dbo.orders")
    count = cursor.fetchone()[0]
    print(f"Connected. orders table has {count:,} rows.")
    conn.close()
