-- Cria as tabelas da camada raw.
-- Guardam os dados como vieram do Kaggle: nomes e valores originais, sem tratamento.
-- Só entram as colunas usadas no projeto (ver docs/dicionario_de_dados.md).
-- A carga é feita pelo script src/load_raw.py.

USE collections_risk;
GO

DROP TABLE IF EXISTS raw.installments_payments;
CREATE TABLE raw.installments_payments (
    SK_ID_PREV              INT,
    SK_ID_CURR              INT,
    NUM_INSTALMENT_VERSION  FLOAT,
    NUM_INSTALMENT_NUMBER   INT,
    DAYS_INSTALMENT         FLOAT,
    DAYS_ENTRY_PAYMENT      FLOAT,
    AMT_INSTALMENT          FLOAT,
    AMT_PAYMENT             FLOAT
);

DROP TABLE IF EXISTS raw.previous_application;
CREATE TABLE raw.previous_application (
    SK_ID_PREV              INT,
    SK_ID_CURR              INT,
    NAME_CONTRACT_TYPE      VARCHAR(30),
    NAME_CONTRACT_STATUS    VARCHAR(30),
    AMT_CREDIT              FLOAT,
    AMT_ANNUITY             FLOAT,
    AMT_DOWN_PAYMENT        FLOAT,
    CNT_PAYMENT             FLOAT,
    DAYS_DECISION           INT,
    DAYS_FIRST_DUE          FLOAT,
    DAYS_LAST_DUE           FLOAT
);

DROP TABLE IF EXISTS raw.application_train;
CREATE TABLE raw.application_train (
    SK_ID_CURR              INT,
    AMT_INCOME_TOTAL        FLOAT,
    DAYS_BIRTH              INT,
    DAYS_EMPLOYED           INT,
    NAME_INCOME_TYPE        VARCHAR(50),
    NAME_EDUCATION_TYPE     VARCHAR(50),
    REGION_RATING_CLIENT    INT
);
GO
