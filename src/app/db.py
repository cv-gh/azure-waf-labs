import os
import struct
import pyodbc


def _get_connection():
    """Create a pyodbc connection to Azure SQL using Managed Identity or SQL auth."""
    server = os.environ["AZURE_SQL_SERVER"]
    database = os.environ["AZURE_SQL_DATABASE"]

    if os.environ.get("AZURE_SQL_USE_MSI", "").lower() == "true":
        import urllib.request
        import json
        token_url = (
            "http://169.254.169.254/metadata/identity/oauth2/token"
            "?api-version=2018-02-01&resource=https://database.windows.net/"
        )
        req = urllib.request.Request(token_url, headers={"Metadata": "true"})
        with urllib.request.urlopen(req) as resp:
            token = json.loads(resp.read())["access_token"]

        token_bytes = token.encode("utf-16-le")
        token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

        conn_str = (
            f"Driver={{ODBC Driver 18 for SQL Server}};"
            f"Server=tcp:{server},1433;"
            f"Database={database};"
            f"Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
        )
        return pyodbc.connect(conn_str, attrs_before={1256: token_struct})

    conn_str = (
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        f"UID={os.environ.get('AZURE_SQL_USER', 'sa')};"
        f"PWD={os.environ['AZURE_SQL_PASSWORD']};"
        f"Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=30;"
    )
    return pyodbc.connect(conn_str)


def seed(conn):
    """Create products and users tables and seed initial data if not present."""
    cursor = conn.cursor()

    cursor.execute("""
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'products')
        CREATE TABLE products (
            id INT IDENTITY(1,1) PRIMARY KEY,
            name NVARCHAR(200) NOT NULL,
            price DECIMAL(10,2) NOT NULL,
            description NVARCHAR(500)
        )
    """)

    cursor.execute("SELECT COUNT(*) FROM products")
    if cursor.fetchone()[0] == 0:
        cursor.executemany(
            "INSERT INTO products (name, price, description) VALUES (?, ?, ?)",
            [
                ("Widget Pro", 9.99, "A standard widget for everyday use"),
                ("Gadget Elite", 19.99, "Advanced gadget with extra features"),
                ("O'Brien Wakeboard", 249.99, "Professional wakeboard by O'Brien"),
                ("O'Brien Life Vest", 79.99, "Safety vest by O'Brien"),
                ("Super Donut", 2.49, "A delicious donut"),
            ],
        )

    cursor.execute("""
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'users')
        CREATE TABLE users (
            id INT IDENTITY(1,1) PRIMARY KEY,
            username NVARCHAR(100) NOT NULL UNIQUE,
            password_hash NVARCHAR(200) NOT NULL
        )
    """)

    cursor.execute("SELECT COUNT(*) FROM users")
    if cursor.fetchone()[0] == 0:
        # Password stored as plaintext intentionally (this is a vulnerable demo app)
        cursor.executemany(
            "INSERT INTO users (username, password_hash) VALUES (?, ?)",
            [("admin", "correct"), ("user1", "password123")],
        )

    conn.commit()
    cursor.close()


class SqlDb:
    """Vulnerable db backed by Azure SQL — intentionally uses f-string SQL."""

    def __init__(self):
        self._conn = _get_connection()
        seed(self._conn)

    def get_products(self):
        cursor = self._conn.cursor()
        cursor.execute("SELECT id, name, price FROM products")
        rows = cursor.fetchall()
        cursor.close()
        return [{"id": r[0], "name": r[1], "price": float(r[2])} for r in rows]

    def search_products(self, query):
        cursor = self._conn.cursor()
        # Intentionally vulnerable: f-string SQL instead of parameterised query
        sql = f"SELECT id, name, price FROM products WHERE name LIKE '%{query}%'"
        try:
            cursor.execute(sql)
            rows = cursor.fetchall()
        except Exception:
            rows = []
        cursor.close()
        return [{"id": r[0], "name": r[1], "price": float(r[2])} for r in rows]

    def check_login(self, username, password):
        cursor = self._conn.cursor()
        # Intentionally vulnerable: f-string SQL instead of parameterised query
        sql = f"SELECT COUNT(*) FROM users WHERE username='{username}' AND password_hash='{password}'"
        try:
            cursor.execute(sql)
            count = cursor.fetchone()[0]
        except Exception:
            count = 0
        cursor.close()
        return count > 0

