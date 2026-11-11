# Dicionário de dados

Tabelas e colunas usadas no projeto, com o nome original da base Home Credit e o nome adotado na camada tratada do SQL Server. Colunas que não aparecem aqui não são usadas.

## Convenções

- **Datas relativas:** a base não traz datas de calendário. Toda data é o número de dias em relação ao pedido atual do cliente. Valores negativos estão no passado (`-365` = um ano antes do pedido).
- **Dias de atraso:** `payment_day - due_day`. Positivo é atraso, zero é pagamento no vencimento, negativo é pagamento antecipado.
- **Valores monetários:** a base não informa a moeda. Os valores são tratados como unidades monetárias, sem conversão.
- **Nomes:** a camada bruta mantém os nomes originais. A camada tratada usa nomes em inglês, em minúsculas e com `_`.

## installments_payments (parcelas)

Histórico de pagamento das parcelas dos contratos. É a tabela central do projeto.

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
| `NAME_CONTRACT_STATUS` | `contract_status` | Situação: aprovado, cancelado, recusado ou oferta não usada |
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
| `DAYS_BIRTH` | `birth_day` | Dia de nascimento (relativo); usado para calcular a idade |
| `DAYS_EMPLOYED` | `employment_start_day` | Início do emprego atual (relativo) |
| `NAME_INCOME_TYPE` | `income_type` | Tipo de renda (assalariado, aposentado, empresário etc.) |
| `NAME_EDUCATION_TYPE` | `education_level` | Escolaridade |
| `REGION_RATING_CLIENT` | `region_rating` | Nota da região onde o cliente mora (1, 2 ou 3) |

**Observação:** 55.374 clientes têm `DAYS_EMPLOYED` igual a 365243, valor que não representa uma data real (equivale a mais de mil anos no futuro). É um código para quem não tem emprego atual, tratado na fase de SQL.

**Fora do projeto:** sexo (`CODE_GENDER`) e estado civil (`NAME_FAMILY_STATUS`), por serem variáveis sensíveis, e `TARGET`, porque o projeto constrói o próprio alvo. Ver `docs/decisoes.md`.
