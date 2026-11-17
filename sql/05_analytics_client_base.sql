-- Camada analytics: base por cliente para o modelo e para o painel.
-- Uma linha por cliente, com:
--   1. comportamento de pagamento até a data de corte (o que o modelo pode olhar);
--   2. situação da carteira no dia do corte, calculada pelas condições dos contratos;
--   3. dados cadastrais;
--   4. resultado no período de previsão (o que o modelo tenta prever).
--
-- Data de corte: dia -365. Período de previsão: do dia -365 ao dia -15
-- (as parcelas dos últimos 15 dias ficam de fora: não houve tempo de observar atraso).
-- Cliente em risco: pelo menos uma parcela do período quitada com mais de 15 dias de atraso,
-- ou não paga. O período considera só contratos que já existiam no dia do corte.
-- Ver docs/decisoes.md, itens 12, 13 e 15.

USE collections_risk;
GO

DROP TABLE IF EXISTS analytics.client_base;

DECLARE @cutoff       INT = -365;  -- data de corte
DECLARE @window_end   INT = -15;   -- fim do período de previsão
DECLARE @recent_start INT = -545;  -- início dos 6 meses anteriores ao corte
DECLARE @late_limit   INT = 15;    -- dias de atraso que definem o risco

WITH installments AS (
    SELECT
        contract_id,
        client_id,
        due_day,
        payment_day,
        amount_due,
        n_payments,
        -- Atraso como era visto no dia do corte. Parcela vencida antes do corte e paga depois
        -- dele estava em aberto no corte: o atraso conta só até o corte, para não usar o futuro.
        CASE
            WHEN n_payments = 0 OR payment_day >= @cutoff THEN @cutoff - due_day
            ELSE payment_day - due_day
        END AS days_late_at_cutoff,
        -- Atraso final, usado só no período de previsão. Parcela não paga conta como o pior caso.
        CASE
            WHEN n_payments = 0 THEN 9999
            ELSE payment_day - due_day
        END AS days_late_final
    FROM staging.installments
    WHERE amount_due > 0
),
history AS (
    -- Comportamento até o corte
    SELECT
        client_id,
        COUNT(DISTINCT contract_id)                                            AS hist_contracts,
        COUNT(*)                                                               AS hist_installments,
        SUM(amount_due)                                                        AS hist_amount_due,
        AVG(CASE WHEN days_late_at_cutoff > 0 THEN 1.0 ELSE 0 END)             AS hist_pct_late,
        AVG(CASE WHEN days_late_at_cutoff > @late_limit THEN 1.0 ELSE 0 END)   AS hist_pct_late_15,
        MAX(days_late_at_cutoff)                                               AS hist_max_days_late,
        AVG(CAST(days_late_at_cutoff AS FLOAT))                                AS hist_avg_days_late,
        AVG(CASE WHEN n_payments > 1 AND payment_day < @cutoff THEN 1.0 ELSE 0 END) AS hist_pct_split_payment,
        -- Últimos 6 meses antes do corte: o atraso recente costuma dizer mais que o antigo
        SUM(CASE WHEN due_day >= @recent_start THEN 1 ELSE 0 END)              AS recent_installments,
        AVG(CASE WHEN due_day >= @recent_start
                 THEN CASE WHEN days_late_at_cutoff > 0 THEN 1.0 ELSE 0 END END) AS recent_pct_late,
        MAX(CASE WHEN due_day >= @recent_start THEN days_late_at_cutoff END)   AS recent_max_days_late,
        -- Parcelas vencidas e ainda sem pagamento no dia do corte
        SUM(CASE WHEN n_payments = 0 OR payment_day >= @cutoff THEN 1 ELSE 0 END) AS open_overdue_installments,
        SUM(CASE WHEN n_payments = 0 OR payment_day >= @cutoff THEN amount_due ELSE 0 END) AS open_overdue_amount
    FROM installments
    WHERE due_day < @cutoff
    GROUP BY client_id
),
contract_schedule AS (
    -- Calendário de cada contrato como era conhecido no dia do corte, pelas condições do contrato:
    -- a parcela k vence em first_due_day + 30 * (k - 1), para k de 1 até o prazo.
    -- due_before_x = quantas parcelas vencem antes do dia x (limitado entre 0 e o prazo).
    SELECT
        client_id,
        decision_day,
        installment_amount,
        term_installments,
        CASE
            WHEN first_due_day IS NULL OR term_installments IS NULL OR term_installments <= 0 THEN NULL
            ELSE term_installments - due.due_before_cutoff
        END AS remaining_after_cutoff,
        CASE
            WHEN first_due_day IS NULL OR term_installments IS NULL OR term_installments <= 0 THEN NULL
            ELSE due.due_before_window_end - due.due_before_cutoff
        END AS installments_in_window
    FROM staging.contracts
    CROSS APPLY (
        SELECT
            CASE
                WHEN first_due_day >= @cutoff THEN 0
                WHEN CEILING((@cutoff - first_due_day) / 30.0) > term_installments THEN term_installments
                ELSE CAST(CEILING((@cutoff - first_due_day) / 30.0) AS INT)
            END AS due_before_cutoff,
            CASE
                WHEN first_due_day >= @window_end THEN 0
                WHEN CEILING((@window_end - first_due_day) / 30.0) > term_installments THEN term_installments
                ELSE CAST(CEILING((@window_end - first_due_day) / 30.0) AS INT)
            END AS due_before_window_end
    ) AS due
    WHERE decision_day < @cutoff
),
portfolio AS (
    -- Situação da carteira do cliente no dia do corte
    SELECT
        client_id,
        SUM(CASE WHEN remaining_after_cutoff > 0 THEN 1 ELSE 0 END)                 AS active_contracts_at_cutoff,
        SUM(CASE WHEN remaining_after_cutoff > 0
                 THEN remaining_after_cutoff * installment_amount ELSE 0 END)         AS scheduled_amount_after_cutoff,
        SUM(CASE WHEN installments_in_window > 0
                 THEN installments_in_window * installment_amount ELSE 0 END)         AS scheduled_window_amount,
        MIN(@cutoff - decision_day)                                                   AS days_since_last_contract,
        SUM(CASE WHEN decision_day >= @cutoff - 365 THEN 1 ELSE 0 END)                AS contracts_last_year
    FROM contract_schedule
    GROUP BY client_id
),
prediction_window AS (
    -- Resultado no período de previsão.
    -- Só entram contratos que já existiam no dia do corte: a pergunta é
    -- "da carteira atual, quem vai atrasar?". Contratos abertos depois do corte
    -- não eram conhecidos e não podem ser cobrados do modelo (ver docs/decisoes.md, item 15).
    SELECT
        i.client_id,
        COUNT(*)               AS window_installments,
        SUM(i.amount_due)      AS window_amount_due,
        MAX(i.days_late_final) AS window_max_days_late
    FROM installments AS i
    INNER JOIN staging.contracts AS c
        ON c.contract_id = i.contract_id
    WHERE i.due_day >= @cutoff
      AND i.due_day < @window_end
      AND c.decision_day < @cutoff
    GROUP BY i.client_id
)
SELECT
    h.client_id,
    -- Histórico
    h.hist_contracts,
    h.hist_installments,
    CAST(h.hist_amount_due AS DECIMAL(18, 2))          AS hist_amount_due,
    CAST(h.hist_pct_late AS DECIMAL(6, 4))             AS hist_pct_late,
    CAST(h.hist_pct_late_15 AS DECIMAL(6, 4))          AS hist_pct_late_15,
    h.hist_max_days_late,
    CAST(h.hist_avg_days_late AS DECIMAL(8, 2))        AS hist_avg_days_late,
    CAST(h.hist_pct_split_payment AS DECIMAL(6, 4))    AS hist_pct_split_payment,
    h.recent_installments,
    CAST(h.recent_pct_late AS DECIMAL(6, 4))           AS recent_pct_late,
    h.recent_max_days_late,
    h.open_overdue_installments,
    CAST(h.open_overdue_amount AS DECIMAL(18, 2))      AS open_overdue_amount,
    -- Carteira no dia do corte (pelas condições dos contratos)
    ISNULL(p.active_contracts_at_cutoff, 0)            AS active_contracts_at_cutoff,
    CAST(ISNULL(p.scheduled_amount_after_cutoff, 0) AS DECIMAL(18, 2)) AS scheduled_amount_after_cutoff,
    CAST(ISNULL(p.scheduled_window_amount, 0) AS DECIMAL(18, 2))       AS scheduled_window_amount,
    p.days_since_last_contract,
    ISNULL(p.contracts_last_year, 0)                   AS contracts_last_year,
    -- Cadastro (vazio para clientes do arquivo de teste do Kaggle, que não tem cadastro carregado)
    CASE WHEN c.client_id IS NULL THEN 0 ELSE 1 END    AS has_profile,
    c.income,
    c.age_years,
    c.years_employed,
    c.no_current_job,
    c.income_type,
    c.education_level,
    c.region_rating,
    -- Período de previsão (o modelo não vê estas colunas)
    w.window_installments,
    CAST(w.window_amount_due AS DECIMAL(18, 2))        AS window_amount_due,
    CASE WHEN w.window_max_days_late > @late_limit THEN 1 ELSE 0 END AS target_late_15,
    CASE WHEN w.window_max_days_late > 30 THEN 1 ELSE 0 END          AS target_late_30
INTO analytics.client_base
FROM history AS h
INNER JOIN prediction_window AS w
    ON w.client_id = h.client_id
LEFT JOIN portfolio AS p
    ON p.client_id = h.client_id
LEFT JOIN staging.clients AS c
    ON c.client_id = h.client_id;

ALTER TABLE analytics.client_base ALTER COLUMN client_id INT NOT NULL;
ALTER TABLE analytics.client_base ADD CONSTRAINT pk_analytics_client_base PRIMARY KEY (client_id);
GO

-- Conferência
SELECT
    COUNT(*)                                                    AS clientes,
    SUM(target_late_15)                                         AS em_risco_15,
    CAST(100.0 * SUM(target_late_15) / COUNT(*) AS DECIMAL(5, 2)) AS pct_risco_15,
    SUM(target_late_30)                                         AS em_risco_30,
    SUM(has_profile)                                            AS com_cadastro
FROM analytics.client_base;

-- Conferência do calendário previsto: o valor previsto no corte deve ficar próximo do cobrado de fato
SELECT
    SUM(CASE WHEN scheduled_window_amount = 0 THEN 1 ELSE 0 END)           AS clientes_sem_valor_previsto,
    CAST(SUM(scheduled_window_amount) AS DECIMAL(18, 0))                   AS valor_previsto_no_corte,
    CAST(SUM(window_amount_due) AS DECIMAL(18, 0))                         AS valor_cobrado_de_fato,
    CAST(SUM(scheduled_window_amount) / SUM(window_amount_due) AS DECIMAL(6, 3)) AS razao_previsto_cobrado,
    CAST(SUM(CASE WHEN target_late_15 = 1 THEN scheduled_window_amount END)
         / NULLIF(SUM(CASE WHEN target_late_15 = 1 THEN window_amount_due END), 0) AS DECIMAL(6, 3)) AS razao_clientes_em_risco,
    SUM(CASE WHEN open_overdue_installments > 0 THEN 1 ELSE 0 END)         AS clientes_com_parcela_em_aberto_no_corte,
    AVG(CAST(active_contracts_at_cutoff AS FLOAT))                         AS media_contratos_ativos
FROM analytics.client_base;
GO
