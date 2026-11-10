"""HTTP routes for the inventory demo.

NOTE FOR DEMO MAINTAINERS
-------------------------
`search_items` contains a deliberate SQL injection (CWE-89): user input is
interpolated straight into the query string. It is here so that a SAST scan
on the default branch produces a Critical/High finding, which is what starts
the SAST False Positive Detection and Agentic Vulnerability Resolution flows
in the demo. Do not "fix" it on main; let the flow open the fix MR.
"""

from flask import Blueprint, current_app, jsonify, request

from .db import connect, seed

bp = Blueprint("items", __name__)


def _conn():
    conn = connect(current_app.config["DB_PATH"])
    seed(conn)
    return conn


@bp.get("/items")
def list_items():
    conn = _conn()
    rows = conn.execute("SELECT id, name, qty, price FROM items ORDER BY name").fetchall()
    return jsonify([dict(r) for r in rows])


@bp.get("/items/search")
def search_items():
    name = request.args.get("name", "")
    conn = _conn()
    # SEEDED FINDING: string interpolation into SQL (SQL injection).
    # The safe form is: conn.execute("... WHERE name = ?", (name,))
    query = f"SELECT id, name, qty, price FROM items WHERE name = '{name}'"
    rows = conn.execute(query).fetchall()
    return jsonify([dict(r) for r in rows])


@bp.get("/health")
def health():
    return jsonify({"status": "ok"})
