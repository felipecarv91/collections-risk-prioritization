"""Conexão com o banco do projeto, usada pelos scripts e notebooks."""

import pyodbc

CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=localhost;"
    "DATABASE=collections_risk;"
    "Trusted_Connection=yes;"       # login do Windows
    "TrustServerCertificate=yes;"   # exigido pelo Driver 18 em conexão local
)


def get_connection() -> pyodbc.Connection:
    """Abre uma conexão com o SQL Server local."""
    return pyodbc.connect(CONNECTION_STRING)
