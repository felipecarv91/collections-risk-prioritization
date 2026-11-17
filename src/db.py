"""Conexão com o banco do projeto, usada pelos scripts e notebooks."""

from urllib.parse import quote_plus

import pyodbc
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine

CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=localhost;"
    "DATABASE=collections_risk;"
    "Trusted_Connection=yes;"       # login do Windows
    "TrustServerCertificate=yes;"   # exigido pelo Driver 18 em conexão local
)


def get_connection() -> pyodbc.Connection:
    """Abre uma conexão direta com o SQL Server local (usada na carga dos dados)."""
    return pyodbc.connect(CONNECTION_STRING)


def get_engine() -> Engine:
    """Cria um engine do SQLAlchemy, o formato que o pandas usa para ler tabelas do banco."""
    return create_engine("mssql+pyodbc:///?odbc_connect=" + quote_plus(CONNECTION_STRING))
