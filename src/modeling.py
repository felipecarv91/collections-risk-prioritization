"""Preparação das variáveis e métricas do modelo de risco."""

import numpy as np
import pandas as pd

from db import read_query

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
    # Carteira no dia do corte, calculada pelas condições dos contratos
    "open_overdue_installments",
    "log_open_overdue_amount",
    "active_contracts_at_cutoff",
    "log_scheduled_amount_after_cutoff",
    "days_since_last_contract",
    "contracts_last_year",
    # Cadastro
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

# Variáveis de carteira no corte, testadas no notebook 02 contra o conjunto original
PORTFOLIO_FEATURES = ["open_overdue_installments", "log_open_overdue_amount", "active_contracts_at_cutoff",
                      "log_scheduled_amount_after_cutoff", "days_since_last_contract", "contracts_last_year"]
PAYMENT_HISTORY_FEATURES = [c for c in BEHAVIOR_FEATURES if c not in PORTFOLIO_FEATURES]

# Tipos de renda com poucos clientes viram "Other" (ver docs/decisoes.md, item 17)
RARE_INCOME_TYPES = ["Unemployed", "Maternity leave", "Student"]


def load_client_base() -> pd.DataFrame:
    """Lê analytics.client_base, com as colunas decimais convertidas para número.

    O ORDER BY fixa a ordem das linhas: sem ele, o banco pode devolver outra ordem,
    e a divisão entre treino e teste e os desempates no ranking mudariam.
    """
    return read_query("SELECT * FROM analytics.client_base ORDER BY client_id",
                      text_columns=CATEGORICAL_FEATURES)


def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    """Monta a tabela de variáveis do modelo a partir da base por cliente."""
    X = pd.DataFrame(index=df.index)
    for col in NUMERIC_FEATURES:
        if col in df.columns:
            X[col] = df[col]

    # Valores monetários têm cauda longa: o logaritmo aproxima clientes muito grandes dos demais
    X["log_hist_amount_due"] = np.log1p(df["hist_amount_due"])
    X["log_income"] = np.log1p(df["income"])
    X["log_open_overdue_amount"] = np.log1p(df["open_overdue_amount"])
    X["log_scheduled_amount_after_cutoff"] = np.log1p(df["scheduled_amount_after_cutoff"])

    # Dias desde o último contrato: limitado a 10 anos, porque valores maiores não diferenciam clientes
    X["days_since_last_contract"] = df["days_since_last_contract"].clip(upper=3650)

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
