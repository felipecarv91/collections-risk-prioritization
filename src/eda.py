"""Funções de apoio à análise exploratória."""

import matplotlib.pyplot as plt
import pandas as pd


def risk_by_group(df: pd.DataFrame, group_col: str, target_col: str = "target_late_15") -> pd.DataFrame:
    """Para cada grupo: quantidade de clientes, % da base, clientes em risco e taxa de risco (%)."""
    table = df.groupby(group_col, observed=True, dropna=False)[target_col].agg(
        clientes="size", em_risco="sum", taxa_risco="mean"
    )
    table["pct_base"] = table["clientes"] / table["clientes"].sum() * 100
    table["taxa_risco"] = table["taxa_risco"] * 100
    return table[["clientes", "pct_base", "em_risco", "taxa_risco"]]


def plot_risk(table: pd.DataFrame, title: str, base_rate: float, ax=None):
    """Barras com a taxa de risco de cada grupo e uma linha com a média da base."""
    ax = ax or plt.gca()
    ax.bar([str(i) for i in table.index], table["taxa_risco"], color="#0d6a68")
    ax.axhline(base_rate, color="#9a6212", linestyle="--", linewidth=1,
               label=f"média da base ({base_rate:.1f}%)")
    ax.set_ylim(0, max(table["taxa_risco"].max(), base_rate) * 1.3)  # espaço para a legenda
    ax.set_title(title)
    ax.set_ylabel("taxa de risco (%)")
    ax.tick_params(axis="x", rotation=30)
    ax.legend(loc="upper left")
    return ax
