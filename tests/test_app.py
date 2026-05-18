import pytest
from app import create_app


class FakeDb:
    """In-memory fake for the db boundary."""

    PRODUCTS = [
        {"id": 1, "name": "Widget", "price": 9.99},
        {"id": 2, "name": "Gadget", "price": 19.99},
    ]

    def get_products(self):
        return self.PRODUCTS

    def search_products(self, query):
        return [p for p in self.PRODUCTS if query.lower() in p["name"].lower()]

    def check_login(self, username, password):
        return username == "admin" and password == "correct"


@pytest.fixture
def client():
    app = create_app(FakeDb())
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


# --- Test 1: tracer bullet ---
def test_products_endpoint_returns_product_list(client):
    response = client.get("/api/products")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)
    assert data[0]["name"] == "Widget"


# --- Test 2 ---
def test_search_returns_results_for_valid_query(client):
    response = client.get("/search?q=widget")
    assert response.status_code == 200
    assert b"Widget" in response.data


# --- Test 3: XSS surface — query reflected unescaped in response ---
def test_search_reflects_query_unescaped(client):
    response = client.get("/search?q=<b>test</b>")
    assert response.status_code == 200
    assert b"<b>test</b>" in response.data


# --- Test 4: FP scenario — apostrophe must not cause 500 ---
def test_search_accepts_apostrophe_without_error(client):
    response = client.get("/search?q=O'Brien")
    assert response.status_code == 200


# --- Test 5: file endpoint returns content ---
def test_file_endpoint_returns_content(client):
    response = client.get("/file?name=readme.txt")
    assert response.status_code == 200
    assert b"Azure WAF" in response.data


# --- Test 6: file endpoint traverses path (intentionally vulnerable) ---
def test_file_endpoint_allows_path_traversal(client):
    # Traverses from src/app/ up two levels to read pytest.ini at the repo root
    response = client.get("/file?name=../../pytest.ini")
    assert response.status_code == 200
    assert b"pytest" in response.data


# --- Test 7: login returns 200 for valid credentials ---
def test_login_succeeds_with_valid_credentials(client):
    response = client.post("/login", data={"username": "admin", "password": "correct"})
    assert response.status_code == 200


# --- Test 8: login returns 401 for invalid credentials ---
def test_login_fails_with_invalid_credentials(client):
    response = client.post("/login", data={"username": "admin", "password": "wrong"})
    assert response.status_code == 401


# --- Test 9: admin page reachable at app layer (WAF blocks by IP, not the app) ---
def test_admin_page_is_reachable(client):
    response = client.get("/admin")
    assert response.status_code == 200


# --- Test 10: attack script guards against missing APPGW_URL ---
def test_attack_script_guards_against_missing_appgw_url():
    import os
    script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts", "attack-part2.sh"))
    with open(script_path) as f:
        content = f.read()
    assert "APPGW_URL" in content
    assert "exit 1" in content
