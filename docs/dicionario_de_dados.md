# Dicionário de dados

Tabelas e colunas usadas no projeto, com o nome original da base Home Credit e o nome adotado na camada tratada do SQL Server. Colunas que não aparecem aqui não são usadas.

## Convenções

- **Datas relativas:** a base não traz datas de calendário. Toda data é o número de dias em relação ao pedido atual do cliente. Valores negativos estão no passado (`-365` = um ano antes do pedido).
- **Dias de atraso:** `payment_day - due_day`. Positivo é atraso, zero é pagamento no vencimento, negativo é pagamento antecipado.
- **Valores monetários:** a base não informa a moeda. Os valores são tratados como unidades monetárias, sem conversão.
- **Nomes:** a camada bruta mantém os nomes originais. A camada tratada usa nomes em inglês, em minúsculas e com `_`.

## installments_payments (parcelas)

Histórico de pagamento das parcelas dos contratos. É a tabela central do projeto.

Na camada staging (`staging.installments`), as linhas são consolidadas em uma por parcela, com duas colunas a mais: `n_payments` (quantidade de pagamentos) e `n_versions` (quantidade de versões do calendário). A regra de consolidação está em `sql/04_staging_installments.sql`.

- **Uma linha:** um pagamento de uma parcela. Uma parcela paga em partes aparece em mais de uma linha.
- **Total:** 13.605.401 linhas.
- **Liga com:** `contracts` por `contract_id` e `clients` por `client_id`.

| Original | Nome no projeto | Descrição |
| --- | --- | --- |
| `SK_ID_PREV` | `contract_id` | Identificador do contrato |
| `SK_ID_CURR` | `client_id` | Identificador do cliente |
| `NUM_INSTALMENT_VERSION` | `calendar_version` | Versão do calendário de parcelas; muda quando algum parâmetro do calendário é alterado (0 indica cartão de crédito) |
| `NUM_INSTALMENT_NUMBER` | `installment_number` | Número da parcela |
| `DAYS_INSTALMENT` | `due_day` | Dia do vencimento (relativo) |
| `DAYS_ENTRY_PAYMENT` | `payment_day` | Dia em que o pagamento foi feito (relativo) |
| `AMT_INSTALMENT` | `amount_due` | Valor devido na parcela |
| `AMT_PAYMENT` | `amount_paid` | Valor efetivamente pago |

**Observação:** 2.905 linhas não têm data nem valor de pagamento. São parcelas registradas sem pagamento, tratadas na fase de SQL.

## previous_application (contratos)

Contratos do cliente na Home Credit.

- **Uma linha:** um contrato (ou pedido de contrato).
- **Total:** 1.670.214 linhas. Após o recorte do projeto (aprovados, sem crédito rotativo), ficam só os empréstimos em dinheiro e as compras parceladas aprovadas.
- **Liga com:** `installments` por `contract_id` e `clients` por `client_id`.

| Original | Nome no projeto | Descrição |
| --- | --- | --- |
| `SK_ID_PREV` | `contract_id` | Identificador do contrato |
| `SK_ID_CURR` | `client_id` | Identificador do cliente |
| `NAME_CONTRACT_TYPE` | `contract_type` | Tipo: empréstimo em dinheiro, compra parcelada ou crédito rotativo |
| `NAME_CONTRACT_STATUS` | (filtro) | Situação: aprovado, cancelado, recusado ou oferta não usada. Usada só no recorte; a camada staging guarda apenas os aprovados |
| `AMT_CREDIT` | `credit_amount` | Valor financiado |
| `AMT_ANNUITY` | `installment_amount` | Valor da parcela prevista no contrato |
| `AMT_DOWN_PAYMENT` | `down_payment` | Valor de entrada |
| `CNT_PAYMENT` | `term_installments` | Prazo em número de parcelas |
| `DAYS_DECISION` | `decision_day` | Dia da aprovação ou recusa (relativo) |
| `DAYS_FIRST_DUE` | `first_due_day` | Dia do primeiro vencimento (relativo) |
| `DAYS_LAST_DUE` | `last_due_day` | Dia do último vencimento (relativo) |

**Observação:** `DAYS_LAST_DUE` também usa o código 365243 em parte dos contratos, no lugar de uma data real. O tratamento é o mesmo do tempo de emprego, na fase de SQL.

## application_train (clientes)

Dados cadastrais do cliente no momento do pedido atual.

- **Uma linha:** um cliente.
- **Total:** 307.511 linhas.
- **Liga com:** `installments` e `contracts` por `client_id`.

| Original | Nome no projeto | Descrição |
| --- | --- | --- |
| `SK_ID_CURR` | `client_id` | Identificador do cliente |
| `AMT_INCOME_TOTAL` | `income` | Renda declarada |
| `DAYS_BIRTH` | `age_years` | Idade em anos, calculada a partir do dia de nascimento relativo |
| `DAYS_EMPLOYED` | `years_employed` | Tempo no emprego atual, em anos. Vazio para quem não tem emprego atual |
| `DAYS_EMPLOYED` | `no_current_job` | 1 quando o cliente não tem emprego atual (código 365243), 0 nos demais casos |
| `NAME_INCOME_TYPE` | `income_type` | Tipo de renda (assalariado, aposentado, empresário etc.) |
| `NAME_EDUCATION_TYPE` | `education_level` | Escolaridade |
| `REGION_RATING_CLIENT` | `region_rating` | Nota da região onde o cliente mora (1, 2 ou 3) |

**Observação:** 55.374 clientes têm `DAYS_EMPLOYED` igual a 365243, valor que não representa uma data real (equivale a mais de mil anos no futuro). É um código para quem não tem emprego atual, tratado na fase de SQL.

**Fora do projeto:** sexo (`CODE_GENDER`) e estado civil (`NAME_FAMILY_STATUS`), por serem variáveis sensíveis, e `TARGET`, porque o projeto constrói o próprio alvo. Ver `docs/decisoes.md`.

## Camada analytics (usada pelo Power BI)

As quatro tabelas se ligam por `client_id`. As três primeiras têm uma linha por cliente; a view tem uma linha por parcela.

### analytics.client_base

Criada em `sql/05_analytics_client_base.sql`. Data de corte no dia -365 e período de previsão do dia -365 ao dia -15 (ver `docs/decisoes.md`, itens 12, 13 e 15). Só entram clientes com parcelas antes do corte e no período de previsão: 156.333 clientes.

| Coluna | Descrição |
| --- | --- |
| `client_id` | Identificador do cliente (chave primária) |
| `hist_contracts` | Contratos com parcelas vencidas antes do corte |
| `hist_installments` | Parcelas vencidas antes do corte |
| `hist_amount_due` | Valor devido somado dessas parcelas |
| `hist_pct_late` | % das parcelas com algum atraso, como era visto no dia do corte |
| `hist_pct_late_15` | % das parcelas com mais de 15 dias de atraso no corte |
| `hist_max_days_late` | Maior atraso no corte, em dias (parcela em aberto conta até o dia do corte) |
| `hist_avg_days_late` | Atraso médio no corte, em dias (negativo é pagamento antecipado) |
| `hist_pct_split_payment` | % das parcelas pagas em mais de um pagamento antes do corte |
| `recent_installments` | Parcelas vencidas nos 6 meses antes do corte (dias -545 a -366) |
| `recent_pct_late` | % dessas parcelas com algum atraso. Vazio para quem não teve parcelas recentes |
| `recent_max_days_late` | Maior atraso nessas parcelas. Vazio para quem não teve parcelas recentes |
| `has_profile` | 1 quando o cliente tem cadastro em `application_train`, 0 quando não tem |
| `income`, `age_years`, `years_employed`, `no_current_job`, `income_type`, `education_level`, `region_rating` | Cadastro, como em `staging.clients`. Vazio quando `has_profile = 0` |
| `window_installments` | Parcelas no período de previsão, só de contratos existentes no corte |
| `window_amount_due` | Valor a receber no período (ver limitação no item 21 de `docs/decisoes.md`) |
| `target_late_15` | 1 quando alguma parcela do período foi paga com mais de 15 dias de atraso ou não foi paga |
| `target_late_30` | O mesmo, com o limite de 30 dias (análise de sensibilidade) |

### analytics.client_scores

Gravada pelo notebook 02.

| Coluna | Descrição |
| --- | --- |
| `client_id` | Identificador do cliente (chave primária) |
| `risk_probability` | Probabilidade calibrada de atraso acima de 15 dias, dada por um modelo que não viu o cliente no treino |
| `expected_value_at_risk` | `risk_probability × window_amount_due` |
| `risk_decile` | Decil de risco pela probabilidade: 1 são os 10% de maior risco |

### analytics.collection_strategy

Gravada pelo notebook 03.

| Coluna | Descrição |
| --- | --- |
| `client_id` | Identificador do cliente (chave primária) |
| `priority_rank` | Posição na fila de cobrança, ordenada pelo valor esperado em risco (1 = primeiro) |
| `collection_action` | Renegociação, Contato, Lembrete ou Monitoramento (ver `docs/decisoes.md`, item 20) |
| `action_order` | Ordem da ação, de 1 (Renegociação) a 4 (Monitoramento), para o Power BI ordenar |

### analytics.installment_status (view)

Criada em `sql/06_analytics_installment_status.sql`. Uma linha por parcela com valor devido maior que zero, no histórico completo (sem data de corte).

| Coluna | Descrição |
| --- | --- |
| `contract_id`, `client_id`, `installment_number` | Identificação da parcela |
| `contract_type` | Empréstimo em dinheiro ou compra parcelada |
| `due_day`, `payment_day` | Vencimento e último pagamento, em dias relativos |
| `amount_due`, `amount_paid` | Valor devido e valor pago |
| `n_payments`, `paid_in_parts` | Quantidade de pagamentos e indicador de pagamento em partes |
| `days_late` | Dias de atraso. Vazio para parcela não paga |
| `amount_status` | Quitada, Quitada parcialmente ou Não paga (ver `docs/decisoes.md`, item 11) |
| `timing_status` | Antecipada, No dia, Atrasada ou Não paga |
| `aging_bucket`, `aging_order` | Faixa de atraso e a ordem dela, para o Power BI ordenar as faixas |
