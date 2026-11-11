-- Análise exploratória: quantas linhas de pagamento cada parcela tem e por quê.
-- Resultado usado para definir como consolidar as parcelas na camada staging.

USE collections_risk;
GO

-- 1. Distribuição de linhas por parcela
-- Resultado: 12.861.994 parcelas; 94,3% com uma linha só, 5,7% (730.634) com duas ou mais.
WITH rows_per_installment AS (
    SELECT
        SK_ID_PREV,
        NUM_INSTALMENT_NUMBER,
        COUNT(*) AS n_rows
    FROM raw.installments_payments
    GROUP BY SK_ID_PREV, NUM_INSTALMENT_NUMBER
)
SELECT
    n_rows,
    COUNT(*) AS installments
FROM rows_per_installment
GROUP BY n_rows
ORDER BY n_rows;
GO

-- 2. Entre as parcelas com mais de uma linha, o que muda entre as linhas
-- Resultado: 640.737 (87,7%) são pagamento em partes (mesma versão, vencimento e valor);
-- 89.897 (12,3%) têm mais de uma versão do calendário; só 303 mudam de vencimento.
WITH multi AS (
    SELECT
        SK_ID_PREV,
        NUM_INSTALMENT_NUMBER,
        COUNT(DISTINCT NUM_INSTALMENT_VERSION) AS n_versions,
        COUNT(DISTINCT DAYS_INSTALMENT)        AS n_due_days,
        COUNT(DISTINCT AMT_INSTALMENT)         AS n_amounts_due
    FROM raw.installments_payments
    GROUP BY SK_ID_PREV, NUM_INSTALMENT_NUMBER
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS installments_multi_rows,
    SUM(CASE WHEN n_versions = 1 AND n_due_days = 1 AND n_amounts_due = 1
             THEN 1 ELSE 0 END)                     AS split_payment_only,
    SUM(CASE WHEN n_versions > 1 THEN 1 ELSE 0 END) AS more_than_one_version,
    SUM(CASE WHEN n_due_days > 1 THEN 1 ELSE 0 END) AS more_than_one_due_day
FROM multi;
GO

-- 3. Exemplos de parcelas com mais de uma versão do calendário
WITH multi_version AS (
    SELECT TOP 3 SK_ID_PREV, NUM_INSTALMENT_NUMBER
    FROM raw.installments_payments
    GROUP BY SK_ID_PREV, NUM_INSTALMENT_NUMBER
    HAVING COUNT(DISTINCT NUM_INSTALMENT_VERSION) > 1
)
SELECT p.*
FROM raw.installments_payments AS p
INNER JOIN multi_version AS m
    ON  p.SK_ID_PREV = m.SK_ID_PREV
    AND p.NUM_INSTALMENT_NUMBER = m.NUM_INSTALMENT_NUMBER
ORDER BY p.SK_ID_PREV, p.NUM_INSTALMENT_NUMBER, p.DAYS_ENTRY_PAYMENT;
GO

-- Resultado da consulta 3: nas três parcelas, o pagamento aparece repetido em cada versão
-- e a soma dos valores devidos das versões é igual ao valor pago
-- (ex.: 16.872,21 + 28.131,30 = 45.003,51).

-- 4. Teste da hipótese em todas as parcelas com mais de uma versão
-- Resultado: 89.897 parcelas; em 89.584 (99,65%) o pagamento é igual em todas as versões
-- e em 89.579 (99,64%) a soma dos devidos bate com o pago. 313 parcelas fogem do padrão.
-- Conclusão: o valor devido é somado entre versões; o valor pago não.
WITH by_version AS (
    SELECT
        SK_ID_PREV,
        NUM_INSTALMENT_NUMBER,
        NUM_INSTALMENT_VERSION,
        MAX(AMT_INSTALMENT) AS amount_due_v,
        SUM(AMT_PAYMENT)    AS amount_paid_v
    FROM raw.installments_payments
    GROUP BY SK_ID_PREV, NUM_INSTALMENT_NUMBER, NUM_INSTALMENT_VERSION
),
by_installment AS (
    SELECT
        SK_ID_PREV,
        NUM_INSTALMENT_NUMBER,
        SUM(amount_due_v)  AS amount_due,
        MIN(amount_paid_v) AS min_paid_v,
        MAX(amount_paid_v) AS max_paid_v
    FROM by_version
    GROUP BY SK_ID_PREV, NUM_INSTALMENT_NUMBER
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS installments,
    SUM(CASE WHEN ABS(max_paid_v - min_paid_v) < 0.01
             THEN 1 ELSE 0 END) AS same_payment_all_versions,
    SUM(CASE WHEN ABS(max_paid_v - amount_due) < 0.01
             THEN 1 ELSE 0 END) AS paid_equals_sum_due
FROM by_installment;
GO
