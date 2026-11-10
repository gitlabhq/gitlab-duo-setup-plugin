"""Inventory demo application factory."""

from flask import Flask

from .db import DEFAULT_DB


def create_app(db_path=DEFAULT_DB):
    app = Flask(__name__)
    app.config["DB_PATH"] = str(db_path)

    from .routes import bp

    app.register_blueprint(bp)
    return app
