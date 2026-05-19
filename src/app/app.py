import os
from flask import Flask, jsonify, redirect, render_template, request, url_for
from markupsafe import Markup


def create_app(db):
    app = Flask(__name__)

    @app.route("/")
    def index():
        return redirect(url_for("search"))

    @app.route("/health")
    def health():
        return jsonify({"status": "ok"}), 200

    @app.route("/api/products")
    def products():
        return jsonify(db.get_products())

    @app.route("/search")
    def search():
        query = request.args.get("q", "")
        results = db.search_products(query)
        # Intentionally vulnerable: Markup() bypasses Jinja2 autoescaping → reflected XSS
        return render_template("search.html", query=Markup(query), products=results,
                               active="search", vuln=True)

    @app.route("/file")
    def file_read():
        name = request.args.get("name", "")
        base_dir = os.path.dirname(os.path.abspath(__file__))
        # Intentionally vulnerable: no path sanitization
        path = os.path.join(base_dir, name)
        try:
            with open(path, "r") as f:
                content = f.read()
            return render_template("file.html", filename=name, content=content,
                                   active="file", vuln=True)
        except FileNotFoundError:
            return render_template("file.html", filename=name, error="File not found",
                                   active="file", vuln=True), 404
        except Exception:
            return render_template("file.html", filename=name, error="Error reading file",
                                   active="file", vuln=True), 500

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "GET":
            return render_template("login.html", active="login", vuln=True)
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        if db.check_login(username, password):
            return render_template("login.html", success="Login successful! Welcome back.",
                                   prefill_username=username, active="login", vuln=True)
        return render_template("login.html", error="Invalid username or password.",
                               prefill_username=username, active="login", vuln=True), 401

    @app.route("/admin")
    def admin():
        products = db.get_products()
        return render_template("admin.html", products=products, active="admin", vuln=True)

    return app
