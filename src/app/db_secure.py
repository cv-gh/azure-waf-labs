import os
import struct
import pyodbc

from db import _get_connection, seed


class SqlDb:
    """Secure db — parameterised queries eliminate SQLi and WAF False Positives."""

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
        try:
            # Parameterised: apostrophes are data, not SQL syntax — no SQLi, no WAF FP
            cursor.execute(
                "SELECT id, name, price FROM products WHERE name LIKE ?",
                [f"%{query}%"],
            )
            rows = cursor.fetchall()
        except Exception:
            rows = []
        cursor.close()
        return [{"id": r[0], "name": r[1], "price": float(r[2])} for r in rows]

    def check_login(self, username, password):
        cursor = self._conn.cursor()
        try:
            # Parameterised: login injection (e.g. ' OR 1=1--) is impossible
            cursor.execute(
                "SELECT COUNT(*) FROM users WHERE username=? AND password_hash=?",
                [username, password],
            )
            count = cursor.fetchone()[0]
        except Exception:
            count = 0
        cursor.close()
        return count > 0

