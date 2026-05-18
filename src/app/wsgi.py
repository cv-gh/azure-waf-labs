from db import SqlDb
from app import create_app

app = create_app(SqlDb())
