import os
from flask import Flask, jsonify, request, render_template_string

SEARCH_TEMPLATE = """
<html><body>
<h1>Search Results for: {{ query | safe }}</h1>
<ul>{% for p in products %}<li>{{ p.name }} - ${{ p.price }}</li>{% endfor %}</ul>
</body></html>
"""

LOGIN_TEMPLATE = """
<html><body>
<h1>Login</h1>
<form method="post">
  <input name="username" placeholder="Username">
  <input name="password" type="password" placeholder="Password">
  <button type="submit">Login</button>
</form>
</body></html>
"""

ADMIN_TEMPLATE = """
<html><body><h1>Admin Panel</h1><p>Welcome, admin.</p></body></html>
"""


def create_app(db):
    app = Flask(__name__)

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
        return render_template_string(SEARCH_TEMPLATE, query=query, products=results)

    @app.route("/file")
    def file_read():
        name = request.args.get("name", "")
        base_dir = os.path.dirname(os.path.abspath(__file__))
        # Intentionally vulnerable: no path sanitization
        path = os.path.join(base_dir, name)
        try:
            with open(path, "r") as f:
                content = f.read()
            return content, 200, {"Content-Type": "text/plain"}
        except FileNotFoundError:
            return "File not found", 404
        except Exception:
            return "Error reading file", 500

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "GET":
            return render_template_string(LOGIN_TEMPLATE)
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        if db.check_login(username, password):
            return "Login successful", 200
        return "Invalid credentials", 401

    @app.route("/admin")
    def admin():
        return render_template_string(ADMIN_TEMPLATE)

    return app
