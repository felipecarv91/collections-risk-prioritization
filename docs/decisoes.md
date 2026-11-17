# Registro de decisões

Decisões relevantes do projeto, com as alternativas consideradas e o motivo de cada escolha.

## 1. Base de dados: Home Credit Default Risk

**Alternativa considerada:** Default of Credit Card Clients (UCI).

**Motivo:** a Home Credit traz o histórico de pagamento por parcela (vencimento, data do pagamento, valor devido e valor pago) em tabelas relacionadas. A UCI é uma tabela única de cartão de crédito rotativo, com histórico mensal agregado, o que não permite analisar parcela por parcela.

## 2. Pergunta de negócio: caixa em risco e régua de cobrança

**Alternativa considerada:** modelo clássico de concessão de crédito, que só separa bons e maus pagadores.

**Motivo:** em crédito parcelado ao consumidor, o atraso afeta diretamente o fluxo de caixa, e a cobrança precisa preservar o relacionamento com o cliente. Por isso o projeto mede o valor esperado em risco e define a abordagem de cobrança de cada cliente.

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

**Motivo:** no histórico completo, 27,7% dos clientes já tiveram atraso acima de 5 dias, 13,3% acima de 15 dias e 5,2% acima de 30 dias (ver `sql/exploration/installment_timing.sql`). Acima de 5 dias marcaria quase um terço da carteira e incluiria atrasos de atrito, como fim de semana e compensação bancária. Acima de 30 dias é o padrão de mercado para inadimplência de crédito, mas seria raro demais na janela de previsão para treinar o modelo. Quinze dias representa atraso que já compromete o caixa do mês, coerente com a pergunta de negócio. Para testar a robustez da escolha, o modelo também foi treinado com o limite de 30 dias (`notebooks/02_modelo.ipynb`, seção 8), e a comparação está no README.

## 13. Data de corte: 365 dias antes do pedido atual

**Regra:** o histórico usado pelo modelo é o de antes do dia -365. O período de previsão vai do dia -365 ao dia -15. Um cliente entra na análise quando tem parcelas nos dois períodos.

**Alternativa considerada:** corte em -180 (previsão de 6 meses).

**Motivo:** o corte em -365 preserva mais clientes (202.341 contra 175.841) e mais que o dobro de casos de risco (3.480 contra 1.558), o que dá mais exemplos para o modelo aprender. Esses números são da comparação feita antes da revisão do item 15, que depois tirou do período de previsão os contratos abertos após o corte; a comparação entre os dois cortes não foi refeita depois disso. Os números da base final estão no item 15. A taxa de risco na janela é de 1,7%: a base é desbalanceada, por isso o modelo será avaliado pela capacidade de ordenar os clientes de risco no topo da lista, e não pela acurácia.

**Censura:** parcelas que vencem nos últimos 15 dias antes do dia 0 ficam fora do período de previsão, porque não houve tempo de observar um atraso acima de 15 dias nelas.

## 14. Base por cliente: clientes sem cadastro e momento do cadastro

**Clientes sem cadastro:** parte dos clientes com parcelas vem do arquivo de teste do Kaggle, que não foi carregado. Eles ficam na base (`has_profile = 0`), com o cadastro vazio, porque o comportamento de pagamento deles é completo e importa para a visão de caixa. Como tratá-los no modelo é decidido na fase de Python.

**Momento do cadastro:** os dados cadastrais (renda, idade, emprego) são do pedido atual, ou seja, posteriores à data de corte. É uma limitação da base, registrada no README. O comportamento de pagamento, principal fonte de informação do modelo, respeita a data de corte.

## 15. Revisão: período de previsão só com contratos existentes no dia do corte

**Problema encontrado na revisão do desenho:** a primeira versão da base por cliente incluía, no período de previsão, parcelas de contratos abertos depois da data de corte. O modelo seria cobrado por prever atrasos em contratos que ninguém conhecia no dia do corte, misturando duas perguntas ("quem da carteira atual vai atrasar" e "quem vai abrir um contrato novo e atrasar"), e o valor a receber incluiria dinheiro que a empresa não tinha como prever.

**Correção:** o período de previsão considera só contratos com decisão anterior ao corte (`decision_day < -365`). A pergunta passa a ser exatamente a da cobrança: da carteira atual, quem vai atrasar.

**Resultado após a correção:** 156.333 clientes, 2.621 em risco pelo critério de 15 dias (1,68%) e 1.095 pelo de 30 dias; 134.105 com cadastro. A taxa de risco ficou praticamente igual à da primeira versão (1,72%), com menos clientes, porque saíram os que só tinham parcelas de contratos novos no período.

**Alternativa considerada:** prever parcela a parcela em vez de cliente a cliente. Daria mais casos de risco, mas tornaria o projeto mais complexo sem mudar a conclusão, e a ação de cobrança é feita por cliente.

## 16. Limitação: todo cliente fez um novo pedido no dia 0

Na base, as datas são relativas a um novo pedido de crédito feito por cada cliente. O período analisado é, portanto, o ano anterior a esse pedido, e quem pede crédito novamente tende a estar em dia. Isso provavelmente reduz a taxa de risco observada. Nenhuma escolha de data de corte elimina esse efeito nesta base; ele fica registrado como limitação no README.

## 17. Decisões da análise exploratória

**Clientes sem cadastro ficam no modelo.** A taxa de risco deles (1,51%) é próxima da dos clientes com cadastro (1,70%), e o comportamento de pagamento deles está completo. Como o modelo final usa só o comportamento (item 19), eles são tratados exatamente como os demais. O indicador `has_profile` e o tratamento dos campos vazios do cadastro ficam só na comparação com cadastro do notebook 02.

**Tipos de renda raros são agrupados.** Desempregado (15 clientes), licença-maternidade (1) e estudante (3) viram "outros": percentuais calculados sobre tão poucos clientes não são confiáveis. O agrupamento vale para a comparação com cadastro e para o painel.

**Prioridade para o comportamento de pagamento.** O histórico e, principalmente, o atraso recente separam o risco muito melhor que o cadastro (ver `notebooks/01_exploracao.ipynb`). O cadastro também é posterior à data de corte, o que reforça usá-lo como informação complementar.

## 18. Desenho do modelo

**Avaliação:** a base é desbalanceada (1,7% em risco), então a métrica principal é a qualidade do topo da lista: precisão média (AP) e o percentual dos casos de risco e do valor em risco capturados nos 10% e 20% de maior score. A AUC é reportada como apoio. A acurácia não é usada.

**Comparação:** uma regra simples (ordenar pelo % de atraso recente) serve de referência; regressão logística e gradient boosting só se justificam se a superarem. O modelo é escolhido por validação cruzada em 5 partes dentro do treino; o teste (30% dos clientes, estratificado) é usado só para medir o modelo já escolhido. Nenhuma escolha do projeto é feita olhando o teste.

**Desbalanceamento:** peso de classe (`class_weight="balanced"`) no treino, seguido de calibração isotônica, porque o peso de classe infla as probabilidades e o valor esperado em risco depende de probabilidades realistas.

**Variáveis fora do modelo:** o valor a receber no período (`window_amount_due`) é usado só para medir o valor em risco, não como variável.

**Scores finais:** cada cliente recebe a probabilidade de um modelo que não o viu no treino (validação cruzada sobre a base inteira), gravada em `analytics.client_scores` com o valor esperado em risco e o decil de risco.

## 19. Modelo final só com o comportamento de pagamento

**Regra:** o modelo final usa só as 11 variáveis de comportamento de pagamento até a data de corte. Renda, idade, emprego, tipo de renda, escolaridade e região ficam de fora.

**Alternativa considerada:** usar também o cadastro.

**Motivo:** o cadastro é do pedido atual, posterior à data de corte (item 14), e não é um critério justo para decidir como cobrar alguém: dois clientes com o mesmo histórico de pagamento devem receber a mesma abordagem. O notebook 02 (seção 8.1) mede o custo dessa escolha por validação cruzada dentro do treino. Com o cadastro, a AUC subiria de 0,755 para 0,763, a precisão média de 0,110 para 0,114 e os casos no top 10% de 45,1% para 45,8%; o valor em risco capturado no top 10% ficaria igual (40,7%). O ganho é pequeno diante dos dois motivos acima.

## 20. Régua de cobrança

**Fila ordenada pelo valor esperado em risco** (probabilidade × valor a receber), e não só pela probabilidade, porque a pergunta do projeto é sobre caixa. O notebook 03 compara as duas filas.

**Quatro ações:** renegociação (10% do topo da fila com atraso acima de 30 dias nos 6 meses antes do corte), contato (restante dos 10% do topo), lembrete (os 20% seguintes) e monitoramento (os 70% restantes). Os cortes de 10% e 30% representam a capacidade de uma equipe que atende pessoalmente 1 em cada 10 clientes e envia mensagens automáticas para mais 2 em cada 10; na prática, seriam ajustados à capacidade real. O resultado fica em `analytics.collection_strategy`.

## 21. Limitação: valor a receber medido pelo que foi cobrado de fato

**O que acontece:** o valor a receber no período (`window_amount_due`) soma as parcelas que de fato apareceram na base entre os dias -365 e -15, e não o calendário de parcelas que a empresa conhecia no dia do corte. Quando um cliente quita um contrato antes do prazo, as parcelas seguintes deixam de existir, e o valor a receber dele fica menor do que o previsto no corte.

**Tamanho:** uma estimativa feita no banco, com meses de 30 dias, indica cerca de 53,9 mil contratos (49,3 mil clientes) existentes no corte e quitados mais de 2 meses antes do previsto dentro do período. Juntos, eles deixaram de faturar algo em torno de 7,4 bilhões, perto de 15% a mais sobre os 41,6 bilhões a receber. O número é aproximado e serve só para dar a ordem de grandeza.

**Efeito:** quem quita antes do prazo costuma ser bom pagador. Com o valor a receber menor, esse cliente desce na fila por valor esperado em risco, o que deixa a régua um pouco melhor na avaliação do que seria na prática. O modelo não é afetado, porque o valor a receber não é variável dele (item 18), e as probabilidades continuam as mesmas.

**Alternativa considerada:** calcular o valor a receber pelo calendário de `staging.contracts` (valor da parcela e prazo), como era conhecido no corte. Ficou de fora para manter a definição simples e coerente com a classificação das parcelas; a limitação fica registrada também no README.
