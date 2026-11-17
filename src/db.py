"""Conexão com o banco do projeto, usada pelos scripts e notebooks."""

from urllib.parse import quote_plus

import pandas as pd
import pyodbc
from sqlalchemy import create_engine, text
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
    return create_engine(
        "mssql+pyodbc:///?odbc_connect=" + quote_plus(CONNECTION_STRING),
        fast_executemany=True,  # grava tabelas em blocos, muito mais rápido que linha a linha
    )


def read_query(query: str, text_columns: list[str] | None = None) -> pd.DataFrame:
    """Executa uma consulta e devolve as colunas numéricas como número.

    O SQL Server devolve as colunas DECIMAL num formato que o pandas trata como texto,
    então tudo o que não está em text_columns é convertido. O client_id fica inteiro.
    """
    df = pd.read_sql(query, get_engine())
    num_cols = df.columns.difference(text_columns or [])
    df[num_cols] = df[num_cols].astype(float)
    if "client_id" in df.columns:
        df["client_id"] = df["client_id"].astype(int)
    return df


def write_table(df: pd.DataFrame, table: str, dtype: dict, primary_key: str = "client_id") -> None:
    """Grava a tabela no schema analytics, substituindo a anterior, e cria a chave primária.

    Os tipos (dtype) são definidos por quem chama, para o banco não ficar com BIGINT e FLOAT
    onde o resto do projeto usa INT e DECIMAL. A chave primária garante uma linha por cliente
    e deixa as consultas do Power BI mais rápidas.
    """
    engine = get_engine()
    df.to_sql(table, engine, schema="analytics", if_exists="replace", index=False,
              chunksize=10_000, dtype=dtype)
    with engine.begin() as conn:
        conn.execute(text(f"ALTER TABLE analytics.{table} ALTER COLUMN {primary_key} INT NOT NULL"))
        conn.execute(text(
            f"ALTER TABLE analytics.{table} "
            f"ADD CONSTRAINT pk_analytics_{table} PRIMARY KEY ({primary_key})"
        ))
