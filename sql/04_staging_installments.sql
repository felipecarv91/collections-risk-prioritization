-- Camada staging: parcelas consolidadas, uma linha por parcela.
--
-- Regra de consolidação (testada em sql/exploration/installment_rows.sql):
-- 1. Dentro de cada versão do calendário, os pagamentos em partes são somados.
-- 2. Entre versões, o valor devido é somado (as versões são partes da mesma parcela),
--    mas o valor pago não, porque o mesmo pagamento aparece repetido em cada versão.
-- 3. O dia do pagamento é o do último pagamento, quando a parcela fica quitada.
-- 4. Parcela sem nenhum pagamento fica com valor pago 0 e dia do pagamento vazio.
-- Só entram parcelas dos contratos do recorte (staging.contracts).

USE collections_risk;
GO

DROP TABLE IF EXISTS staging.installments;

WITH by_version AS (
    -- Etapa 1: uma linha por parcela e versão
    SELECT
        SK_ID_PREV,
        SK_ID_CURR,
        NUM_INSTALMENT_NUMBER,
        NUM_INSTALMENT_VERSION,
        MIN(DAYS_INSTALMENT)    AS due_day,
        MAX(AMT_INSTALMENT)     AS amount_due,
        SUM(AMT_PAYMENT)        AS amount_paid,
        MAX(DAYS_ENTRY_PAYMENT) AS last_payment_day,
        COUNT(AMT_PAYMENT)      AS n_payments
    FROM raw.installments_payments
    GROUP BY SK_ID_PREV, SK_ID_CURR, NUM_INSTALMENT_NUMBER, NUM_INSTALMENT_VERSION
),
by_installment AS (
    -- Etapa 2: uma linha por parcela
    SELECT
        SK_ID_PREV,
        SK_ID_CURR,
        NUM_INSTALMENT_NUMBER,
        COUNT(*)              AS n_versions,
        MIN(due_day)          AS due_day,
        SUM(amount_due)       AS amount_due,
        MAX(amount_paid)      AS amount_paid,
        MAX(last_payment_day) AS payment_day,
        MAX(n_payments)       AS n_payments
    FROM by_version
    GROUP BY SK_ID_PREV, SK_ID_CURR, NUM_INSTALMENT_NUMBER
)
SELECT
    i.SK_ID_PREV                                      AS contract_id,
    i.SK_ID_CURR                                      AS client_id,
    i.NUM_INSTALMENT_NUMBER                           AS installment_number,
    CAST(i.due_day AS INT)                            AS due_day,
    CAST(i.payment_day AS INT)                        AS payment_day,
    CAST(i.amount_due AS DECIMAL(18, 3))              AS amount_due,
    CAST(ISNULL(i.amount_paid, 0) AS DECIMAL(18, 3))  AS amount_paid,
    i.n_payments,
    i.n_versions
INTO staging.installments
FROM by_installment AS i
INNER JOIN staging.contracts AS c
    ON c.contract_id = i.SK_ID_PREV;

-- Chave primária: garante uma linha por parcela de cada contrato
ALTER TABLE staging.installments ALTER COLUMN contract_id INT NOT NULL;
ALTER TABLE staging.installments ALTER COLUMN installment_number INT NOT NULL;
ALTER TABLE staging.installments
    ADD CONSTRAINT pk_staging_installments PRIMARY KEY (contract_id, installment_number);
CREATE INDEX ix_staging_installments_client ON staging.installments (client_id);
GO

-- Conferência
SELECT
    COUNT(*)                                          AS parcelas,
    COUNT(DISTINCT contract_id)                       AS contratos,
    COUNT(DISTINCT client_id)                         AS clientes,
    SUM(CASE WHEN n_payments = 0 THEN 1 ELSE 0 END)   AS parcelas_sem_pagamento,
    SUM(CASE WHEN n_payments > 1 THEN 1 ELSE 0 END)   AS parcelas_pagas_em_partes,
    SUM(CASE WHEN n_versions > 1 THEN 1 ELSE 0 END)   AS parcelas_com_mais_de_uma_versao
FROM staging.installments;
GO
