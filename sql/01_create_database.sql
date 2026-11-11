-- Cria o banco do projeto e as três camadas de dados.
-- raw: cópia fiel dos arquivos do Kaggle
-- staging: dados tratados, com nomes padronizados e recorte aplicado
-- analytics: tabelas prontas para análise, uma linha por cliente

IF DB_ID('collections_risk') IS NULL
    CREATE DATABASE collections_risk;
GO

USE collections_risk;
GO

IF SCHEMA_ID('raw') IS NULL EXEC('CREATE SCHEMA raw');
IF SCHEMA_ID('staging') IS NULL EXEC('CREATE SCHEMA staging');
IF SCHEMA_ID('analytics') IS NULL EXEC('CREATE SCHEMA analytics');
GO
