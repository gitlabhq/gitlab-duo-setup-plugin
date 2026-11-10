import pytest

from app import create_app


@pytest.fixture()
def client(tmp_path):
    app = create_app(db_path=tmp_path / "test.db")
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


def test_list_items_returns_seed_rows(client):
    rows = client.get("/items").get_json()
    names = [r["name"] for r in rows]
    assert names == ["gadget", "gizmo", "sprocket", "widget"]


def test_search_by_name(client):
    rows = client.get("/items/search?name=widget").get_json()
    assert len(rows) == 1
    assert rows[0]["qty"] == 12
