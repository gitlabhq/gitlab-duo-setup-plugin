"""SQLite data layer for the inventory demo.

Deliberately small: one table, a seed function, and a connection helper.
The schema is created on first use so tests and the dev server need no setup.
"""

import sqlite3
from pathlib import Path

DEFAULT_DB = Path(__file__).resolve().parent.parent / "inventory.db"

SEED_ITEMS = [
    ("widget", 12, 2.50),
    ("gadget", 3, 19.99),
    ("sprocket", 0, 0.75),
    ("gizmo", 7, 5.00),
]


def connect(db_path=DEFAULT_DB):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute(
        "CREATE TABLE IF NOT EXISTS items ("
        "  id INTEGER PRIMARY KEY,"
        "  name TEXT NOT NULL UNIQUE,"
        "  qty INTEGER NOT NULL,"
        "  price REAL NOT NULL"
        ")"
    )
    return conn


def seed(conn):
    """Insert the demo rows if the table is empty."""
    count = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
    if count == 0:
        conn.executemany(
            "INSERT INTO items (name, qty, price) VALUES (?, ?, ?)", SEED_ITEMS
        )
        conn.commit()
