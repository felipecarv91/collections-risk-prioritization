# Registro de decisões

Decisões relevantes do projeto, com as alternativas consideradas e o motivo de cada escolha.

## 1. Base de dados: Home Credit Default Risk

**Alternativa considerada:** Default of Credit Card Clients (UCI).

**Motivo:** a Home Credit traz o histórico de pagamento por parcela (vencimento, data do pagamento, valor devido e valor pago) em tabelas relacionadas. A UCI é uma tabela única de cartão de crédito rotativo, com histórico mensal agregado, o que não permite analisar parcela por parcela.

## 2. Pergunta de negócio: caixa em risco e régua de cobrança

**Alternativa considerada:** modelo clássico de concessão de crédito, que só separa bons e maus pagadores.

**Motivo:** em serviços pré-pagos parcelados, o atraso afeta principalmente o fluxo de caixa, e a cobrança precisa preservar o relacionamento com o cliente. Por isso o projeto mede o valor esperado em risco e define a abordagem de cobrança de cada cliente.

## 3. Escopo: 3 das 7 tabelas

Uso de `installments_payments`, `previous_application` e `application_train`, além do dicionário de colunas. As demais tabelas aumentariam o tempo do projeto sem mudar a resposta à pergunta de negócio.

## 4. Banco de dados: SQL Server 2025 Developer

**Alternativas consideradas:** PostgreSQL, MySQL e DuckDB.

**Motivo:** integração nativa com o Power BI, presença frequente em vagas de BI no Brasil e capacidade para o volume do projeto (13,6 milhões de linhas na tabela de parcelas). A edição Developer é gratuita para desenvolvimento e estudo e tem todos os recursos. A edição Express foi descartada porque limita a memória usada pelo banco, o que deixaria lentas as consultas nesse volume.

## 5. Ambiente Python isolado

Ambiente conda próprio (`collections-risk`), com versões fixas em `environment.yml`, para que o projeto seja reproduzido exatamente como foi desenvolvido.

## 6. Convenção de idioma

Nomes de tabelas, colunas e variáveis em inglês. Comentários no código em português.
