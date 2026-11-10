#!/usr/bin/env bash
# demo/seed-mr.sh — stage Scenario 1/2: an "agent-written" merge request whose
# pipeline fails.
#
# Creates branch feat/low-stock-report with a new endpoint that has an
# off-by-one bug (uses < where the spec says "at or below"), plus a test that
# asserts the inclusive behavior. The MR pipeline fails on that test, which
# starts the Fix CI/CD Pipeline flow (inline suggestions on the MR), while
# Code Review Flow reviews the change.
#
# Run from the repository root on a clean main. Pushes and opens the MR.

set -euo pipefail

BRANCH="feat/low-stock-report"

git checkout -q main
git pull -q --ff-only
git checkout -q -b "$BRANCH"

cat > app/reports.py <<'EOF'
"""Inventory reports."""

from flask import Blueprint, current_app, jsonify, request

from .db import connect, seed

bp = Blueprint("reports", __name__)


def low_stock(conn, threshold):
    """Return items whose quantity is at or below ``threshold``."""
    rows = conn.execute(
        "SELECT id, name, qty, price FROM items WHERE qty < ? ORDER BY qty, name",
        (threshold,),
    ).fetchall()
    return [dict(r) for r in rows]


@bp.get("/reports/low-stock")
def low_stock_report():
    threshold = request.args.get("threshold", default=5, type=int)
    conn = connect(current_app.config["DB_PATH"])
    seed(conn)
    return jsonify(low_stock(conn, threshold))
EOF

python3 - <<'EOF'
from pathlib import Path
p = Path("app/__init__.py")
s = p.read_text()
s = s.replace(
    "    from .routes import bp\n\n    app.register_blueprint(bp)\n",
    "    from .routes import bp\n    from .reports import bp as reports_bp\n\n"
    "    app.register_blueprint(bp)\n    app.register_blueprint(reports_bp)\n",
)
p.write_text(s)
EOF

cat > tests/test_reports.py <<'EOF'
import pytest

from app import create_app


@pytest.fixture()
def client(tmp_path):
    app = create_app(db_path=tmp_path / "test.db")
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_low_stock_is_inclusive_of_threshold(client):
    # Seed quantities: widget 12, gadget 3, sprocket 0, gizmo 7.
    # "At or below 3" must include gadget (qty == 3).
    rows = client.get("/reports/low-stock?threshold=3").get_json()
    assert [r["name"] for r in rows] == ["sprocket", "gadget"]


def test_low_stock_default_threshold(client):
    rows = client.get("/reports/low-stock").get_json()
    assert [r["name"] for r in rows] == ["sprocket", "gadget"]
EOF

git add app/reports.py app/__init__.py tests/test_reports.py
git commit -q -m "feat(reports): add low-stock report endpoint

Adds GET /reports/low-stock?threshold=N returning items at or below the
threshold, default 5."

git push -q -u origin "$BRANCH" \
  -o merge_request.create \
  -o merge_request.title="feat(reports): add low-stock report endpoint" \
  -o merge_request.description="Adds \`GET /reports/low-stock?threshold=N\`, returning items whose quantity is at or below the threshold (default 5). Agent-written change for the recommended-configuration demo."

echo
echo "Pushed $BRANCH and opened the MR."
echo "Expected: Code Review runs; the MR pipeline fails on tests/test_reports.py;"
echo "Fix CI/CD Pipeline (if its trigger is set) posts a suggestion changing '<' to '<='."
