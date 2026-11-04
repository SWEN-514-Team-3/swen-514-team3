"""One-time database setup for Meeting Momentum.

Runs inside the VPC (the database is private). Applies schema.sql, then
seed.sql, and returns the row count of every table. Both files are safe to
run again: the schema uses IF NOT EXISTS and the seed skips existing rows.

The Setup workflow invokes this with the database login in the event:
    {"username": "...", "password": "..."}
The login is never logged or returned.
"""
import os
import ssl
from pathlib import Path

import pg8000.native

HERE = Path(__file__).parent
SQL_FILES = ("schema.sql", "seed.sql")
TABLES = (
    "users",
    "meetings",
    "meeting_participants",
    "decisions",
    "action_items",
    "uploaded_files",
    "ai_results",
)


def connect(username, password):
    ssl_context = None
    if os.environ.get("DB_SSL", "true").lower() != "false":
        # RDS requires TLS. The database is only reachable from inside the
        # VPC, so encrypt the connection without checking the certificate
        # (the RDS CA bundle is not packaged with this function).
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
    return pg8000.native.Connection(
        user=username,
        password=password,
        host=os.environ["DB_HOST"],
        port=5432,
        database=os.environ["DB_NAME"],
        ssl_context=ssl_context,
        timeout=30,
    )


def lambda_handler(event, context):
    username = event.get("username")
    password = event.get("password")
    if not username or not password:
        raise ValueError("The event must include username and password.")

    conn = connect(username, password)
    try:
        for name in SQL_FILES:
            conn.run((HERE / name).read_text())
        counts = {table: conn.run(f"SELECT count(*) FROM {table}")[0][0] for table in TABLES}
    finally:
        conn.close()

    return {"applied": list(SQL_FILES), "row_counts": counts}
