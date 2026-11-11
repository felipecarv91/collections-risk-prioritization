-- Camada staging: contratos e clientes tratados.
-- Aplica o recorte do projeto, padroniza os nomes das colunas (ver docs/dicionario_de_dados.md)
-- e trata o código 365243, que a base usa no lugar de datas inexistentes.

USE collections_risk;
GO

-- Contratos: só os aprovados e parcelados (empréstimo em dinheiro e compra parcelada).
-- Cancelados, recusados e crédito rotativo ficam de fora (ver docs/decisoes.md, item 7).
DROP TABLE IF EXISTS staging.contracts;

SELECT
    SK_ID_PREV                                  AS contract_id,
    SK_ID_CURR                                  AS client_id,
    NAME_CONTRACT_TYPE                          AS contract_type,
    CAST(AMT_CREDIT AS DECIMAL(18, 3))          AS credit_amount,
    CAST(AMT_ANNUITY AS DECIMAL(18, 3))         AS installment_amount,
    CAST(AMT_DOWN_PAYMENT AS DECIMAL(18, 3))    AS down_payment,
    CAST(CNT_PAYMENT AS INT)                    AS term_installments,
    DAYS_DECISION                               AS decision_day,
    -- 365243 não é uma data: vira vazio (NULL)
    CAST(NULLIF(DAYS_FIRST_DUE, 365243) AS INT) AS first_due_day,
    CAST(NULLIF(DAYS_LAST_DUE, 365243) AS INT)  AS last_due_day
INTO staging.contracts
FROM raw.previous_application
WHERE NAME_CONTRACT_STATUS = 'Approved'
  AND NAME_CONTRACT_TYPE IN ('Cash loans', 'Consumer loans');

-- Chave primária: garante um contrato por linha
ALTER TABLE staging.contracts ALTER COLUMN contract_id INT NOT NULL;
ALTER TABLE staging.contracts ADD CONSTRAINT pk_staging_contracts PRIMARY KEY (contract_id);
CREATE INDEX ix_staging_contracts_client ON staging.contracts (client_id);
GO

-- Clientes: idade e tempo de emprego em anos, mais legíveis que dias relativos.
-- Sexo e estado civil não são carregados (ver docs/decisoes.md, item 8).
DROP TABLE IF EXISTS staging.clients;

SELECT
    SK_ID_CURR                                       AS client_id,
    CAST(AMT_INCOME_TOTAL AS DECIMAL(18, 2))         AS income,
    CAST(-DAYS_BIRTH / 365.25 AS INT)                AS age_years,
    -- 365243 indica cliente sem emprego atual: vira NULL, com uma coluna própria para o caso
    CAST(-NULLIF(DAYS_EMPLOYED, 365243) / 365.25 AS DECIMAL(5, 1)) AS years_employed,
    CASE WHEN DAYS_EMPLOYED = 365243 THEN 1 ELSE 0 END AS no_current_job,
    NAME_INCOME_TYPE                                 AS income_type,
    NAME_EDUCATION_TYPE                              AS education_level,
    REGION_RATING_CLIENT                             AS region_rating
INTO staging.clients
FROM raw.application_train;

ALTER TABLE staging.clients ALTER COLUMN client_id INT NOT NULL;
ALTER TABLE staging.clients ADD CONSTRAINT pk_staging_clients PRIMARY KEY (client_id);
GO

-- Conferência
SELECT 'staging.contracts' AS tabela, COUNT(*) AS linhas FROM staging.contracts
UNION ALL
SELECT 'staging.clients', COUNT(*) FROM staging.clients
UNION ALL
SELECT 'clientes sem emprego atual', SUM(no_current_job) FROM staging.clients;
GO
