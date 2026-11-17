"""Preparação das variáveis e métricas do modelo de risco."""

import numpy as np
import pandas as pd

from db import get_engine

# Variáveis numéricas: comportamento de pagamento até o corte e cadastro
NUMERIC_FEATURES = [
    "hist_contracts",
    "hist_installments",
    "log_hist_amount_due",
    "hist_pct_late",
    "hist_pct_late_15",
    "hist_max_days_late",
    "hist_avg_days_late",
    "hist_pct_split_payment",
    "recent_installments",
    "recent_pct_late",
    "recent_max_days_late",
    "has_profile",
    "log_income",
    "age_years",
    "years_employed",
    "no_current_job",
    "region_rating",
]
CATEGORICAL_FEATURES = ["income_type", "education_level"]
FEATURES = NUMERIC_FEATURES + CATEGORICAL_FEATURES

# Dados cadastrais: são do pedido atual, posterior à data de corte.
# O modelo final usa só o comportamento de pagamento (ver docs/decisoes.md, item 19);
# o cadastro é usado apenas na comparação do notebook 02 e no painel.
PROFILE_NUMERIC = ["has_profile", "log_income", "age_years", "years_employed",
                   "no_current_job", "region_rating"]
BEHAVIOR_FEATURES = [c for c in NUMERIC_FEATURES if c not in PROFILE_NUMERIC]

# Tipos de renda com poucos clientes viram "Other" (ver docs/decisoes.md, item 17)
RARE_INCOME_TYPES = ["Unemployed", "Maternity leave", "Student", "Businessman"]

TEXT_COLUMNS = ["income_type", "education_level"]


def load_client_base() -> pd.DataFrame:
    """Lê analytics.client_base e converte as colunas decimais para número."""
    df = pd.read_sql("SELECT * FROM analytics.client_base", get_engine())
    num_cols = df.columns.difference(TEXT_COLUMNS)
    df[num_cols] = df[num_cols].astype(float)
    df["client_id"] = df["client_id"].astype(int)
    return df


def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    """Monta a tabela de variáveis do modelo a partir da base por cliente."""
    X = pd.DataFrame(index=df.index)
    for col in NUMERIC_FEATURES:
        if col in df.columns:
            X[col] = df[col]

    # Valores monetários têm cauda longa: o logaritmo aproxima clientes muito grandes dos demais
    X["log_hist_amount_due"] = np.log1p(df["hist_amount_due"])
    X["log_income"] = np.log1p(df["income"])

    # Atrasos extremos (parcelas em aberto há anos) são limitados a 365 dias
    for col in ["hist_max_days_late", "hist_avg_days_late", "recent_max_days_late"]:
        X[col] = df[col].clip(lower=-60, upper=365)

    # Categorias: clientes sem cadastro ganham uma categoria própria
    X["income_type"] = df["income_type"].replace({t: "Other" for t in RARE_INCOME_TYPES}).fillna("No profile")
    X["education_level"] = df["education_level"].fillna("No profile")

    return X[FEATURES]


def capture_at_top(y, score, value, share: float) -> tuple[float, float]:
    """Quanto dos casos de risco (e do valor deles) está no topo da lista ordenada pelo score.

    Retorna (% dos clientes em risco capturados, % do valor dos clientes em risco capturado).
    """
    y = np.asarray(y)
    value = np.asarray(value)
    n_top = int(np.ceil(share * len(y)))
    top = np.argsort(-np.asarray(score), kind="stable")[:n_top]
    pct_cases = y[top].sum() / y.sum()
    pct_value = (value * y)[top].sum() / (value * y).sum()
    return pct_cases, pct_value


def gains_curve(y, score) -> tuple[np.ndarray, np.ndarray]:
    """Curva de ganho: % da base contatada (eixo x) e % dos casos de risco alcançados (eixo y)."""
    y = np.asarray(y)
    order = np.argsort(-np.asarray(score), kind="stable")
    cum_cases = np.cumsum(y[order]) / y.sum()
    pct_base = np.arange(1, len(y) + 1) / len(y)
    return np.r_[0, pct_base], np.r_[0, cum_cases]
