-- Camada analytics: classificação de cada parcela, usada no painel do Power BI.
-- É uma view: uma consulta salva que se comporta como tabela, sempre atualizada
-- com os dados da camada staging.
--
-- Regras (ver docs/decisoes.md, itens 11 e 12):
-- - Valor: quitada com pelo menos 99% do devido; abaixo disso, quitada parcialmente;
--   sem nenhum pagamento, não paga. Parcelas com valor devido zero ficam de fora.
-- - Prazo: dias de atraso = dia do último pagamento - dia do vencimento.

USE collections_risk;
GO

CREATE OR ALTER VIEW analytics.installment_status AS
SELECT
    i.contract_id,
    i.client_id,
    c.contract_type,
    i.installment_number,
    i.due_day,
    i.payment_day,
    i.amount_due,
    i.amount_paid,
    i.n_payments,
    CASE WHEN i.n_payments > 1 THEN 1 ELSE 0 END AS paid_in_parts,
    CASE WHEN i.n_payments = 0 THEN NULL ELSE i.payment_day - i.due_day END AS days_late,

    -- Status pelo valor
    CASE
        WHEN i.n_payments = 0                     THEN 'Não paga'
        WHEN i.amount_paid >= 0.99 * i.amount_due THEN 'Quitada'
        ELSE                                           'Quitada parcialmente'
    END AS amount_status,

    -- Status pelo prazo
    CASE
        WHEN i.n_payments = 0              THEN 'Não paga'
        WHEN i.payment_day < i.due_day     THEN 'Antecipada'
        WHEN i.payment_day = i.due_day     THEN 'No dia'
        ELSE                                    'Atrasada'
    END AS timing_status,

    -- Faixa de atraso (aging), com uma coluna de ordem para o Power BI ordenar as faixas
    CASE
        WHEN i.n_payments = 0                     THEN 'Não paga'
        WHEN i.payment_day - i.due_day <= 0       THEN 'Sem atraso'
        WHEN i.payment_day - i.due_day <= 5       THEN '1 a 5 dias'
        WHEN i.payment_day - i.due_day <= 15      THEN '6 a 15 dias'
        WHEN i.payment_day - i.due_day <= 30      THEN '16 a 30 dias'
        WHEN i.payment_day - i.due_day <= 60      THEN '31 a 60 dias'
        WHEN i.payment_day - i.due_day <= 90      THEN '61 a 90 dias'
        ELSE                                           'Mais de 90 dias'
    END AS aging_bucket,
    CASE
        WHEN i.n_payments = 0                     THEN 8
        WHEN i.payment_day - i.due_day <= 0       THEN 1
        WHEN i.payment_day - i.due_day <= 5       THEN 2
        WHEN i.payment_day - i.due_day <= 15      THEN 3
        WHEN i.payment_day - i.due_day <= 30      THEN 4
        WHEN i.payment_day - i.due_day <= 60      THEN 5
        WHEN i.payment_day - i.due_day <= 90      THEN 6
        ELSE                                           7
    END AS aging_order
FROM staging.installments AS i
INNER JOIN staging.contracts AS c
    ON c.contract_id = i.contract_id
WHERE i.amount_due > 0;
GO

-- Conferência: parcelas por faixa de atraso
SELECT
    aging_order,
    aging_bucket,
    COUNT(*) AS parcelas,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5, 2)) AS pct
FROM analytics.installment_status
GROUP BY aging_order, aging_bucket
ORDER BY aging_order;
GO
