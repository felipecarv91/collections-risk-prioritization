# Priorização de cobrança por risco de inadimplência

Análise de uma carteira de recebíveis parcelados para estimar quanto do caixa previsto está em risco e definir a abordagem de cobrança mais adequada para cada cliente: lembrete, contato ou renegociação.

**Status:** em desenvolvimento.

## Pergunta de negócio

Quanto do caixa previsto está em risco e quais clientes devem receber cada tipo de abordagem para recuperar esse valor sem desgastar o relacionamento?

## Ferramentas

- **SQL Server:** carga, tratamento e agregação dos dados
- **Python:** análise exploratória, modelo de risco e segmentação (pandas, scikit-learn)
- **Power BI:** painel de acompanhamento da cobrança

## Dados

Base pública [Home Credit Default Risk](https://www.kaggle.com/competitions/home-credit-default-risk), do Kaggle. As regras da competição não permitem redistribuir os arquivos, por isso eles não estão neste repositório.

Para reproduzir o projeto:

1. Aceite as regras da competição no Kaggle e baixe os dados.
2. Extraia os arquivos na pasta `data/raw/`.

## Ambiente

```bash
conda env create -f environment.yml
conda activate collections-risk
```
