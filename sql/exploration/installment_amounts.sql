-- Análise exploratória: como o valor pago se compara ao valor devido, por parcela consolidada.
-- Resultado: 99,96% das parcelas foram pagas no valor exato. Pagas a menos: 2.247 (0,03%),
-- sendo 386 com diferença de até 1% e 1.861 acima de 1%. Sem pagamento: 1.152.
-- Valor devido zero: 185. A mais, acima de 1%: 1.
-- Conclusão: o risco desta carteira está no prazo de pagamento, não no valor.

USE collections_risk;
GO

WITH diff AS (
    SELECT
        CASE
            WHEN n_payments = 0                       THEN '0. sem pagamento'
            WHEN amount_due = 0                       THEN '1. valor devido zero'
            WHEN amount_paid = amount_due             THEN '2. exato'
            WHEN ABS(amount_paid - amount_due) < 1    THEN '3. diferença menor que 1'
            WHEN amount_paid < amount_due
             AND (amount_due - amount_paid) / amount_due <= 0.01 THEN '4. a menos, até 1%'
            WHEN amount_paid < amount_due             THEN '5. a menos, mais de 1%'
            WHEN (amount_paid - amount_due) / amount_due <= 0.01 THEN '6. a mais, até 1%'
            ELSE                                           '7. a mais, mais de 1%'
        END AS faixa
    FROM staging.installments
)
SELECT
    faixa,
    COUNT(*) AS parcelas,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5, 2)) AS pct
FROM diff
GROUP BY faixa
ORDER BY faixa;
GO
