"""Executa o projeto inteiro, em ordem: banco, carga, transformações e notebooks.

Uso, a partir da pasta do projeto, com o ambiente ativado (conda activate collections-risk):

    python run_pipeline.py              # tudo, inclusive a carga dos CSVs (cerca de 15 minutos a mais)
    python run_pipeline.py --skip-load  # parte da camada raw já carregada: scripts 03 a 06 e notebooks

Os scripts SQL são executados pelo próprio Python (pyodbc), sem depender do SSMS ou do sqlcmd.
Cada script termina com uma consulta de conferência, cujo resultado é impresso no terminal.
"""

import argparse
import asyncio
import re
import subprocess
import sys
import time
from pathlib import Path

# No Windows, o Jupyter precisa deste tipo de laço de eventos; sem ele, aparece um aviso a cada notebook
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

ROOT = Path(__file__).resolve().parent
sys.path.append(str(ROOT / "src"))

from db import CONNECTION_STRING  # noqa: E402

import nbformat  # noqa: E402
import pyodbc  # noqa: E402
from nbclient import NotebookClient  # noqa: E402

SQL_SETUP = ["01_create_database.sql", "02_create_raw_tables.sql"]
SQL_TRANSFORM = [
    "03_staging_contracts_clients.sql",
    "04_staging_installments.sql",
    "05_analytics_client_base.sql",
    "06_analytics_installment_status.sql",
]
NOTEBOOKS = ["01_exploracao.ipynb", "02_modelo.ipynb", "03_regua_de_cobranca.ipynb"]


def run_sql_file(path: Path) -> None:
    """Executa um script SQL dividido em blocos pelo separador GO e imprime as conferências."""
    batches = [b for b in re.split(r"^\s*GO\s*$", path.read_text(encoding="utf-8"),
                                   flags=re.MULTILINE | re.IGNORECASE) if b.strip()]
    # Conecta no banco master: o script 01 cria o banco do projeto, e os demais começam com USE
    conn_str = CONNECTION_STRING.replace("DATABASE=collections_risk;", "DATABASE=master;")
    with pyodbc.connect(conn_str, autocommit=True) as conn:
        cursor = conn.cursor()
        for batch in batches:
            cursor.execute(batch)
            while True:
                if cursor.description:
                    columns = [c[0] for c in cursor.description]
                    for row in cursor.fetchall():
                        print("   ", dict(zip(columns, row)))
                if not cursor.nextset():
                    break


def run_notebook(path: Path) -> None:
    """Executa o notebook do início ao fim, num kernel limpo, e grava os resultados no próprio arquivo."""
    notebook = nbformat.read(path, as_version=4)
    # kernel "python3": o Python do ambiente ativado; a pasta de trabalho é a do notebook
    NotebookClient(notebook, timeout=None, kernel_name="python3",
                   resources={"metadata": {"path": str(path.parent)}}).execute()
    nbformat.write(notebook, path)


def step(label: str, func, path: Path) -> None:
    start = time.time()
    print(f"\n>> {label}: {path.name}")
    func(path)
    print(f"   concluído em {time.time() - start:.0f}s")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--skip-load", action="store_true",
                        help="não recria nem recarrega a camada raw (usa os dados já carregados)")
    args = parser.parse_args()

    if not args.skip_load:
        for name in SQL_SETUP:
            step("SQL", run_sql_file, ROOT / "sql" / name)
        start = time.time()
        print("\n>> Carga dos CSVs na camada raw")
        subprocess.run([sys.executable, str(ROOT / "src" / "load_raw.py")], check=True)
        print(f"   concluído em {time.time() - start:.0f}s")

    for name in SQL_TRANSFORM:
        step("SQL", run_sql_file, ROOT / "sql" / name)
    for name in NOTEBOOKS:
        step("Notebook", run_notebook, ROOT / "notebooks" / name)

    print("\nProjeto executado do início ao fim.")


if __name__ == "__main__":
    main()
