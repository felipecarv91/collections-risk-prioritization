-- Análise exploratória: em quantos dias, em relação ao vencimento, as parcelas foram quitadas.
-- Dias de atraso = dia do último pagamento - dia do vencimento.

USE collections_risk;
GO

-- 1. Distribuição das parcelas por faixa de atraso, em quantidade e em valor
-- Resultado: antecipada 82,84% das parcelas (85,49% do valor); no dia 6,83% (7,04%);
-- 1 a 5 dias 6,48% (5,22%); 6 a 15 dias 2,44% (1,59%); 16 a 30 dias 1,08% (0,54%);
-- 31 a 60 dias 0,19% (0,08%); 61 a 90 dias 0,03% (0,01%); mais de 90 dias 0,09% (0,02%);
-- não paga 0,01% (0,02%).
-- Conclusão: 10,3% das parcelas atrasam, quase sempre por poucos dias.
WITH timing AS (
    SELECT
        amount_due,
        CASE
            WHEN n_payments = 0               THEN '0. não paga'
            WHEN payment_day - due_day < 0    THEN '1. antecipada'
            WHEN payment_day - due_day = 0    THEN '2. no dia'
            WHEN payment_day - due_day <= 5   THEN '3. 1 a 5 dias'
            WHEN payment_day - due_day <= 15  THEN '4. 6 a 15 dias'
            WHEN payment_day - due_day <= 30  THEN '5. 16 a 30 dias'
            WHEN payment_day - due_day <= 60  THEN '6. 31 a 60 dias'
            WHEN payment_day - due_day <= 90  THEN '7. 61 a 90 dias'
            ELSE                                   '8. mais de 90 dias'
        END AS faixa
    FROM staging.installments
    WHERE amount_due > 0
)
SELECT
    faixa,
    COUNT(*) AS parcelas,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5, 2))               AS pct_parcelas,
    CAST(100.0 * SUM(amount_due) / SUM(SUM(amount_due)) OVER () AS DECIMAL(5, 2)) AS pct_valor
FROM timing
GROUP BY faixa
ORDER BY faixa;
GO

-- 2. Percentual de clientes com pelo menos uma parcela acima de cada limite de atraso
-- (parcela não paga conta como o pior atraso possível)
WITH client_max AS (
    SELECT
        client_id,
        MAX(CASE WHEN n_payments = 0 THEN 9999
                 ELSE payment_day - due_day END) AS max_days_late
    FROM staging.installments
    WHERE amount_due > 0
    GROUP BY client_id
)
SELECT
    COUNT(*) AS clientes,
    CAST(100.0 * SUM(CASE WHEN max_days_late > 5  THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 2)) AS pct_mais_5_dias,
    CAST(100.0 * SUM(CASE WHEN max_days_late > 15 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 2)) AS pct_mais_15_dias,
    CAST(100.0 * SUM(CASE WHEN max_days_late > 30 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 2)) AS pct_mais_30_dias
FROM client_max;
GO

-- 3. Quantos clientes cada data de corte preserva e quantos ficam em risco
-- (histórico antes do corte; período de previsão do corte até o dia -15)
-- Resultado: corte -365: 202.341 clientes, 3.480 em risco (1,7%);
--            corte -180: 175.841 clientes, 1.558 em risco (0,9%).
-- Conclusão: corte em -365.
WITH per_client AS (
    SELECT
        client_id,
        SUM(CASE WHEN due_day < -365 THEN 1 ELSE 0 END)                   AS hist_365,
        SUM(CASE WHEN due_day >= -365 AND due_day < -15 THEN 1 ELSE 0 END) AS window_365,
        MAX(CASE WHEN due_day >= -365 AND due_day < -15
                 THEN CASE WHEN n_payments = 0 THEN 9999 ELSE payment_day - due_day END
            END)                                                          AS max_late_365,
        SUM(CASE WHEN due_day < -180 THEN 1 ELSE 0 END)                   AS hist_180,
        SUM(CASE WHEN due_day >= -180 AND due_day < -15 THEN 1 ELSE 0 END) AS window_180,
        MAX(CASE WHEN due_day >= -180 AND due_day < -15
                 THEN CASE WHEN n_payments = 0 THEN 9999 ELSE payment_day - due_day END
            END)                                                          AS max_late_180
    FROM staging.installments
    WHERE amount_due > 0
    GROUP BY client_id
)
SELECT
    SUM(CASE WHEN hist_365 > 0 AND window_365 > 0 THEN 1 ELSE 0 END)                       AS clientes_corte_365,
    SUM(CASE WHEN hist_365 > 0 AND window_365 > 0 AND max_late_365 > 15 THEN 1 ELSE 0 END) AS em_risco_365,
    SUM(CASE WHEN hist_180 > 0 AND window_180 > 0 THEN 1 ELSE 0 END)                       AS clientes_corte_180,
    SUM(CASE WHEN hist_180 > 0 AND window_180 > 0 AND max_late_180 > 15 THEN 1 ELSE 0 END) AS em_risco_180
FROM per_client;
GO
