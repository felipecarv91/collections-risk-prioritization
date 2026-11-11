"""Carrega os CSVs do Kaggle nas tabelas da camada raw do SQL Server.

Pré-requisitos:
- arquivos extraídos em data/raw/
- tabelas criadas com sql/02_create_raw_tables.sql

Uso, a partir da pasta do projeto:
    python src/load_raw.py
"""

import time
from pathlib import Path

import pandas as pd

from db import get_connection

RAW_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"
CHUNK_SIZE = 200_000  # linhas lidas e gravadas por vez, para não estourar a memória

# Arquivo de origem -> (tabela de destino, colunas usadas no projeto)
TABLES = {
    "installments_payments.csv": (
        "raw.installments_payments",
        ["SK_ID_PREV", "SK_ID_CURR", "NUM_INSTALMENT_VERSION", "NUM_INSTALMENT_NUMBER",
         "DAYS_INSTALMENT", "DAYS_ENTRY_PAYMENT", "AMT_INSTALMENT", "AMT_PAYMENT"],
    ),
    "previous_application.csv": (
        "raw.previous_application",
        ["SK_ID_PREV", "SK_ID_CURR", "NAME_CONTRACT_TYPE", "NAME_CONTRACT_STATUS",
         "AMT_CREDIT", "AMT_ANNUITY", "AMT_DOWN_PAYMENT", "CNT_PAYMENT",
         "DAYS_DECISION", "DAYS_FIRST_DUE", "DAYS_LAST_DUE"],
    ),
    "application_train.csv": (
        "raw.application_train",
        ["SK_ID_CURR", "AMT_INCOME_TOTAL", "DAYS_BIRTH", "DAYS_EMPLOYED",
         "NAME_INCOME_TYPE", "NAME_EDUCATION_TYPE", "REGION_RATING_CLIENT"],
    ),
}


def load_table(conn, csv_name: str, table: str, columns: list[str]) -> None:
    """Esvazia a tabela e grava o CSV nela em blocos."""
    cursor = conn.cursor()
    cursor.fast_executemany = True  # envia cada bloco de uma vez, em vez de linha a linha

    cursor.execute(f"TRUNCATE TABLE {table}")  # permite rodar a carga de novo sem duplicar
    insert_sql = (
        f"INSERT INTO {table} ({', '.join(columns)}) "
        f"VALUES ({', '.join('?' * len(columns))})"
    )

    start = time.time()
    total = 0
    for chunk in pd.read_csv(RAW_DIR / csv_name, usecols=columns, chunksize=CHUNK_SIZE):
        chunk = chunk[columns]
        # Campos vazios do CSV viram NULL no banco
        chunk = chunk.astype(object).where(chunk.notna(), None)
        cursor.executemany(insert_sql, chunk.values.tolist())
        conn.commit()
        total += len(chunk)
        print(f"  {table}: {total:,} linhas ({time.time() - start:.0f}s)")

    # Confere se tudo o que foi lido chegou ao banco
    in_db = cursor.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    status = "OK" if in_db == total else "DIVERGENTE"
    print(f"{table}: {in_db:,} linhas no banco, {total:,} no arquivo. {status}\n")


def main() -> None:
    with get_connection() as conn:
        for csv_name, (table, columns) in TABLES.items():
            print(f"Carregando {csv_name} em {table}")
            load_table(conn, csv_name, table, columns)


if __name__ == "__main__":
    main()
