"""HTTP routes for the inventory demo.

`search_items` is the route `demo/seed-sast.sh` makes vulnerable for the SAST
remediation scenario. Keep it parameterized on main.
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
    rows = conn.execute(
        "SELECT id, name, qty, price FROM items WHERE name = ?", (name,)
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@bp.get("/health")
def health():
    return jsonify({"status": "ok"})
