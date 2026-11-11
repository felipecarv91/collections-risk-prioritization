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

## 10. Carga da camada raw por Python

**Alternativa considerada:** `BULK INSERT`, executado pelo próprio SQL Server.

**Motivo:** o `BULK INSERT` lê o arquivo com a conta do serviço do SQL Server, que não tem acesso às pastas do usuário no Windows. Usá-lo exigiria alterar permissões de pasta em cada computador onde o projeto rodar. O script `src/load_raw.py` lê os CSVs em blocos com pandas e grava pelo `pyodbc`, funciona em qualquer máquina com o ambiente do projeto e confere ao final se o total de linhas no banco bate com o do arquivo. As tabelas continuam definidas em SQL (`sql/02_create_raw_tables.sql`).

## 11. Classificação da parcela pelo valor pago

**Regra:** quitada quando o valor pago é de pelo menos 99% do valor devido (tolerância de 1% para arredondamentos); quitada parcialmente quando fica abaixo disso; não paga quando não há nenhum pagamento; parcelas com valor devido zero ficam fora da análise. Pagamento acima do devido conta como quitada.

**Motivo:** 99,96% das parcelas foram pagas no valor exato (ver `sql/exploration/installment_amounts.sql`). Como a diferença de valor afeta pouquíssimas parcelas, uma regra simples é suficiente, e a tolerância evita marcar como devedor quem deixou de pagar centavos. O risco relevante desta carteira está no prazo de pagamento.

## 12. Definição de cliente em risco: atraso acima de 15 dias

**Regra:** um cliente é considerado em risco quando tem pelo menos uma parcela quitada com mais de 15 dias de atraso, ou não paga, no período observado.

**Alternativas consideradas:** mais de 5 dias e mais de 30 dias.

**Motivo:** no histórico completo, 27,7% dos clientes já tiveram atraso acima de 5 dias, 13,3% acima de 15 dias e 5,2% acima de 30 dias (ver `sql/exploration/installment_timing.sql`). Acima de 5 dias marcaria quase um terço da carteira e incluiria atrasos de atrito, como fim de semana e compensação bancária. Acima de 30 dias é o padrão de mercado para inadimplência de crédito, mas seria raro demais na janela de previsão para treinar o modelo. Quinze dias representa atraso que já compromete o caixa do mês, coerente com a pergunta de negócio. Para testar a robustez da escolha, o modelo também será treinado com o limite de 30 dias, e a comparação será apresentada no README.

## 13. Data de corte: 365 dias antes do pedido atual

**Regra:** o histórico usado pelo modelo é o de antes do dia -365. O período de previsão vai do dia -365 ao dia -15. Um cliente entra na análise quando tem parcelas nos dois períodos.

**Alternativa considerada:** corte em -180 (previsão de 6 meses).

**Motivo:** o corte em -365 preserva mais clientes (202.341 contra 175.841) e mais que o dobro de casos de risco (3.480 contra 1.558), o que dá mais exemplos para o modelo aprender. A taxa de risco na janela é de 1,7%: a base é desbalanceada, por isso o modelo será avaliado pela capacidade de ordenar os clientes de risco no topo da lista, e não pela acurácia.

**Censura:** parcelas que vencem nos últimos 15 dias antes do dia 0 ficam fora do período de previsão, porque não houve tempo de observar um atraso acima de 15 dias nelas.

## 14. Base por cliente: clientes sem cadastro e momento do cadastro

**Clientes sem cadastro:** parte dos clientes com parcelas vem do arquivo de teste do Kaggle, que não foi carregado. Eles ficam na base (`has_profile = 0`), com o cadastro vazio, porque o comportamento de pagamento deles é completo e importa para a visão de caixa. Como tratá-los no modelo é decidido na fase de Python.

**Momento do cadastro:** os dados cadastrais (renda, idade, emprego) são do pedido atual, ou seja, posteriores à data de corte. É uma limitação da base, registrada no README. O comportamento de pagamento, principal fonte de informação do modelo, respeita a data de corte.
