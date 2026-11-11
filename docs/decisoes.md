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

## 7. Recorte: contratos aprovados e parcelados

**Alternativa considerada:** usar todos os 1.670.214 contratos da tabela `previous_application`.

**Motivo:** só contratos aprovados geram parcelas e cobrança. Cancelados (316.319), recusados (290.678) e ofertas não usadas (26.436) nunca tiveram pagamento. O crédito rotativo (193.164 contratos) também fica de fora, porque funciona como cartão de crédito, sem parcela fixa nem vencimento definido, e distorceria a análise de atraso. Ficam os empréstimos em dinheiro (`Cash loans`) e as compras parceladas (`Consumer loans`).

## 8. Variáveis sensíveis fora da análise

Sexo (`CODE_GENDER`) e estado civil (`NAME_FAMILY_STATUS`) não entram no modelo nem na priorização. Além do risco de viés, não são critérios justos para definir como cobrar um cliente.

## 9. Alvo próprio, sem a coluna TARGET

A coluna `TARGET` de `application_train` é o alvo da competição do Kaggle, com uma definição de atraso que não é pública por completo. O projeto constrói o próprio alvo a partir da tabela de parcelas e de uma data de corte, para controlar exatamente o que está sendo previsto.
