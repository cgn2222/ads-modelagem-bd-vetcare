# 04 — Dicionário de Dados

Dicionário completo das **16 tabelas** do banco `vetcare` (MySQL 8.0, modelo lógico em **3FN**), gerado a partir do DDL em [`sql/01_ddl_schema.sql`](../sql/01_ddl_schema.sql). Os nomes de tabelas, colunas, tipos e restrições são exatamente os do script físico.

**Legenda das restrições:** `PK` chave primária · `FK` chave estrangeira · `UQ` UNIQUE · `NN` NOT NULL · `NULL` aceita nulo · `AI` AUTO_INCREMENT · `CK` CHECK · `DF` DEFAULT.

**Convenções de tipos:** chaves substitutas `INT AUTO_INCREMENT`; códigos de tamanho fixo `CHAR` (CEP 8, CPF 11, UF 2, microchip 15); dinheiro `DECIMAL(10,2)` (nunca `FLOAT`); peso `DECIMAL(5,2)`; `DATE`/`DATETIME` para datas; `TEXT` para textos longos; `ENUM` para domínios fechados; `BOOLEAN` para flags. Charset `utf8mb4`, collation `utf8mb4_0900_ai_ci`, engine InnoDB.

## Índice

| # | Tabela | Domínio | PK | Colunas | FKs |
|:-:|---|---|---|:-:|:-:|
| 1 | [`endereco_cep`](#1-endereco_cep) | Catálogos/Domínio | `cep` | 5 | 0 |
| 2 | [`tutor`](#2-tutor) | Cadastros | `id_tutor` | 8 | 1 |
| 3 | [`telefone_tutor`](#3-telefone_tutor) | Cadastros | `id_tutor, numero_telefone` | 4 | 1 |
| 4 | [`especie`](#4-especie) | Catálogos/Domínio | `id_especie` | 2 | 0 |
| 5 | [`raca`](#5-raca) | Catálogos/Domínio | `id_raca` | 3 | 1 |
| 6 | [`animal`](#6-animal) | Cadastros | `id_animal` | 9 | 2 |
| 7 | [`prontuario`](#7-prontuario) | Clínico | `id_animal` | 4 | 1 |
| 8 | [`especialidade`](#8-especialidade) | Catálogos/Domínio | `id_especialidade` | 2 | 0 |
| 9 | [`veterinario`](#9-veterinario) | Cadastros | `id_veterinario` | 7 | 1 |
| 10 | [`consulta`](#10-consulta) | Clínico | `id_consulta` | 8 | 2 |
| 11 | [`consulta_sintoma`](#11-consulta_sintoma) | Clínico | `id_consulta, descricao_sintoma` | 2 | 1 |
| 12 | [`procedimento`](#12-procedimento) | Catálogos/Domínio | `id_procedimento` | 3 | 0 |
| 13 | [`consulta_procedimento`](#13-consulta_procedimento) | Clínico | `id_consulta, id_procedimento` | 4 | 2 |
| 14 | [`categoria_medicamento`](#14-categoria_medicamento) | Catálogos/Domínio | `id_categoria_medicamento` | 3 | 0 |
| 15 | [`medicamento`](#15-medicamento) | Catálogos/Domínio | `id_medicamento` | 6 | 1 |
| 16 | [`prescricao`](#16-prescricao) | Clínico | `id_consulta, id_medicamento` | 5 | 2 |

## 1. `endereco_cep`

**Domínio:** Catálogos/Domínio · **Descrição:** Tabela de domínio de endereçamento. Cada CEP identifica um único logradouro/bairro/cidade/UF (extraída na 3FN: cep → logradouro, bairro, cidade, uf).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `cep` | `CHAR(8)` | PK; NN | CEP sem máscara (8 dígitos). Chave natural. |
| `logradouro` | `VARCHAR(120)` | NN | Nome da rua/avenida. |
| `bairro` | `VARCHAR(80)` | NN | Bairro. |
| `cidade` | `VARCHAR(80)` | NN | Cidade. |
| `uf` | `CHAR(2)` | NN | Sigla da unidade federativa. |

## 2. `tutor`

**Domínio:** Cadastros · **Descrição:** Responsável pelo animal (dado pessoal protegido pela LGPD). Endereço composto resolvido na 1FN: CEP (FK) + número + complemento.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_tutor` | `INT` | PK; NN; AI | Identificador substituto (surrogate) do tutor. |
| `nome` | `VARCHAR(100)` | NN | Nome completo. |
| `cpf` | `CHAR(11)` | NN; UQ; CK `ck_tutor_cpf_formato`: `cpf REGEXP '^[0-9]{11}$'` | CPF somente com dígitos (11). Único por tutor. |
| `email` | `VARCHAR(120)` | NULL; UQ | E-mail de contato (opcional, único quando informado). |
| `data_cadastro` | `DATE` | NN; DF `(CURRENT_DATE)` | Data de cadastro; por padrão, a data corrente. |
| `cep` | `CHAR(8)` | FK → `endereco_cep.cep`; NN | CEP do endereço; referencia `endereco_cep`. |
| `numero` | `VARCHAR(10)` | NN | Número do imóvel (texto, aceita 'S/N'). |
| `complemento` | `VARCHAR(60)` | NULL | Complemento (apto, sala, casa...). |

**Chaves estrangeiras:**

- `fk_tutor_cep`: `cep` → `endereco_cep.cep` — ON DELETE RESTRICT ON UPDATE CASCADE

**Índices adicionais:** `uq_tutor_cpf` (UNIQUE: cpf); `uq_tutor_email` (UNIQUE: email); `ix_tutor_nome` (nome)

## 3. `telefone_tutor`

**Domínio:** Cadastros · **Descrição:** Entidade fraca criada na 1FN para o atributo multivalorado `telefone` do tutor. Uma linha por telefone.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_tutor` | `INT` | PK (composta); FK → `tutor.id_tutor`; NN | Tutor dono do telefone; parte da PK composta. |
| `numero_telefone` | `VARCHAR(15)` | PK (composta); NN | Número com DDD, somente dígitos; parte da PK composta. |
| `tipo` | `ENUM('CELULAR','RESIDENCIAL','COMERCIAL')` | NN; DF `'CELULAR'` | Tipo de linha: CELULAR, RESIDENCIAL ou COMERCIAL. |
| `whatsapp` | `BOOLEAN` | NN; DF `FALSE` | Indica se o número possui WhatsApp. |

**Chaves estrangeiras:**

- `fk_telefone_tutor`: `id_tutor` → `tutor.id_tutor` — ON DELETE CASCADE ON UPDATE CASCADE

## 4. `especie`

**Domínio:** Catálogos/Domínio · **Descrição:** Tabela de domínio das espécies atendidas (extraída na 3FN: id_raca → id_especie → nome_especie).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_especie` | `INT` | PK; NN; AI | Identificador da espécie. |
| `nome_especie` | `VARCHAR(50)` | NN; UQ | Nome da espécie (único). |

**Índices adicionais:** `uq_especie_nome` (UNIQUE: nome_especie)

## 5. `raca`

**Domínio:** Catálogos/Domínio · **Descrição:** Tabela de domínio das raças; cada raça pertence a uma única espécie.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_raca` | `INT` | PK; NN; AI | Identificador da raça. |
| `id_especie` | `INT` | FK → `especie.id_especie`; NN; UQ (com `nome_raca`) | Espécie da raça; referencia `especie`. |
| `nome_raca` | `VARCHAR(80)` | NN; UQ (com `id_especie`) | Nome da raça; único dentro da espécie. |

**Chaves estrangeiras:**

- `fk_raca_especie`: `id_especie` → `especie.id_especie` — ON DELETE RESTRICT ON UPDATE CASCADE

**Índices adicionais:** `uq_raca_especie_nome` (UNIQUE: id_especie, nome_raca)

## 6. `animal`

**Domínio:** Cadastros · **Descrição:** Paciente da clínica. A idade é atributo derivado (calculada a partir de `data_nascimento`) e por isso NÃO é armazenada.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_animal` | `INT` | PK; NN; AI | Identificador do animal. |
| `id_tutor` | `INT` | FK → `tutor.id_tutor`; NN | Tutor responsável; referencia `tutor`. |
| `id_raca` | `INT` | FK → `raca.id_raca`; NN | Raça do animal; referencia `raca` (a espécie é obtida pela raça). |
| `nome` | `VARCHAR(80)` | NN | Nome do animal. |
| `sexo` | `ENUM('M','F')` | NN | Sexo: M (macho) ou F (fêmea). |
| `data_nascimento` | `DATE` | NN | Data de nascimento (base do cálculo da idade). |
| `peso_kg` | `DECIMAL(5,2)` | NN; CK `ck_animal_peso`: `peso_kg > 0` | Peso atual em kg; deve ser maior que zero. |
| `microchip` | `CHAR(15)` | NULL; UQ | Número do microchip (15 dígitos); opcional e único. |
| `ativo` | `BOOLEAN` | NN; DF `TRUE` | Indica se o paciente segue ativo na clínica. |

**Chaves estrangeiras:**

- `fk_animal_tutor`: `id_tutor` → `tutor.id_tutor` — ON DELETE RESTRICT ON UPDATE CASCADE
- `fk_animal_raca`: `id_raca` → `raca.id_raca` — ON DELETE RESTRICT ON UPDATE CASCADE

**Índices adicionais:** `uq_animal_microchip` (UNIQUE: microchip); `ix_animal_nome` (nome)

## 7. `prontuario`

**Domínio:** Clínico · **Descrição:** Entidade fraca 1:1 identificada pelo animal (PK = FK). Ficha clínica única do animal.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_animal` | `INT` | PK; FK → `animal.id_animal`; NN | Animal dono do prontuário; PK herdada. |
| `data_abertura` | `DATE` | NN | Data de abertura do prontuário. |
| `alergias_conhecidas` | `TEXT` | NULL | Alergias conhecidas (texto livre). |
| `observacoes_gerais` | `TEXT` | NULL | Observações gerais do histórico (texto livre). |

**Chaves estrangeiras:**

- `fk_prontuario_animal`: `id_animal` → `animal.id_animal` — ON DELETE RESTRICT ON UPDATE CASCADE

## 8. `especialidade`

**Domínio:** Catálogos/Domínio · **Descrição:** Tabela de domínio das especialidades veterinárias (extraída na 3FN).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_especialidade` | `INT` | PK; NN; AI | Identificador da especialidade. |
| `nome_especialidade` | `VARCHAR(60)` | NN; UQ | Nome da especialidade (único). |

**Índices adicionais:** `uq_especialidade_nome` (UNIQUE: nome_especialidade)

## 9. `veterinario`

**Domínio:** Cadastros · **Descrição:** Profissional habilitado (CRMV) responsável pelas consultas.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_veterinario` | `INT` | PK; NN; AI | Identificador do veterinário. |
| `nome` | `VARCHAR(100)` | NN | Nome completo. |
| `crmv` | `VARCHAR(10)` | NN; UQ (com `uf_crmv`) | Número do registro no CRMV. |
| `uf_crmv` | `CHAR(2)` | NN; UQ (com `crmv`) | UF do conselho regional; forma o par único com `crmv`. |
| `email` | `VARCHAR(120)` | NN; UQ | E-mail profissional (único). |
| `id_especialidade` | `INT` | FK → `especialidade.id_especialidade`; NN | Especialidade principal; referencia `especialidade`. |
| `ativo` | `BOOLEAN` | NN; DF `TRUE` | Indica se o profissional está ativo. |

**Chaves estrangeiras:**

- `fk_vet_especialidade`: `id_especialidade` → `especialidade.id_especialidade` — ON DELETE RESTRICT ON UPDATE CASCADE

**Índices adicionais:** `uq_vet_crmv` (UNIQUE: crmv, uf_crmv); `uq_vet_email` (UNIQUE: email)

## 10. `consulta`

**Domínio:** Clínico · **Descrição:** Evento central do negócio: relaciona animal e veterinário em data/hora. O valor total é derivado (SUM em `consulta_procedimento`) e não é armazenado.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_consulta` | `INT` | PK; NN; AI | Identificador da consulta. |
| `id_animal` | `INT` | FK → `animal.id_animal`; NN | Animal atendido; referencia `animal`. |
| `id_veterinario` | `INT` | FK → `veterinario.id_veterinario`; NN | Veterinário responsável; referencia `veterinario`. |
| `data_hora` | `DATETIME` | NN | Data e hora agendadas/realizadas. |
| `motivo` | `VARCHAR(200)` | NN | Motivo da consulta. |
| `diagnostico` | `TEXT` | NULL | Diagnóstico (texto livre; nulo até a consulta ser realizada). |
| `status` | `ENUM('AGENDADA','REALIZADA','CANCELADA')` | NN; DF `'AGENDADA'` | Situação: AGENDADA, REALIZADA ou CANCELADA. |
| `caminho_laudo_pdf` | `VARCHAR(255)` | NULL | Caminho do laudo em PDF (o arquivo fica fora do banco). |

**Chaves estrangeiras:**

- `fk_consulta_animal`: `id_animal` → `animal.id_animal` — ON DELETE RESTRICT ON UPDATE CASCADE
- `fk_consulta_vet`: `id_veterinario` → `veterinario.id_veterinario` — ON DELETE RESTRICT ON UPDATE CASCADE

**Índices adicionais:** `ix_consulta_data` (data_hora); `ix_consulta_status_data` (status, data_hora)

## 11. `consulta_sintoma`

**Domínio:** Clínico · **Descrição:** Entidade fraca criada na 1FN para o atributo multivalorado `sintoma` da consulta.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_consulta` | `INT` | PK (composta); FK → `consulta.id_consulta`; NN | Consulta de origem; parte da PK composta. |
| `descricao_sintoma` | `VARCHAR(100)` | PK (composta); NN | Descrição do sintoma relatado; parte da PK composta. |

**Chaves estrangeiras:**

- `fk_sintoma_consulta`: `id_consulta` → `consulta.id_consulta` — ON DELETE CASCADE ON UPDATE CASCADE

## 12. `procedimento`

**Domínio:** Catálogos/Domínio · **Descrição:** Catálogo de serviços cobrados (consulta, vacinas, exames, cirurgias simples).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_procedimento` | `INT` | PK; NN; AI | Identificador do procedimento. |
| `nome_procedimento` | `VARCHAR(100)` | NN; UQ | Nome do procedimento (único). |
| `valor_padrao` | `DECIMAL(10,2)` | NN; CK `ck_procedimento_valor`: `valor_padrao >= 0` | Valor de tabela em R$; o valor efetivamente cobrado fica em `consulta_procedimento`. |

**Índices adicionais:** `uq_procedimento_nome` (UNIQUE: nome_procedimento)

## 13. `consulta_procedimento`

**Domínio:** Clínico · **Descrição:** Tabela associativa N:M entre consulta e procedimento (2FN). Guarda o que foi executado e cobrado.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_consulta` | `INT` | PK (composta); FK → `consulta.id_consulta`; NN | Consulta; parte da PK composta. |
| `id_procedimento` | `INT` | PK (composta); FK → `procedimento.id_procedimento`; NN | Procedimento; parte da PK composta. |
| `quantidade` | `INT` | NN; DF `1`; CK `ck_cp_quantidade`: `quantidade > 0` | Quantidade executada (maior que zero). |
| `valor_cobrado` | `DECIMAL(10,2)` | NN; CK `ck_cp_valor`: `valor_cobrado >= 0` | Valor unitário efetivamente cobrado em R$ (pode diferir do valor padrão). |

**Chaves estrangeiras:**

- `fk_cp_consulta`: `id_consulta` → `consulta.id_consulta` — ON DELETE RESTRICT ON UPDATE CASCADE
- `fk_cp_procedimento`: `id_procedimento` → `procedimento.id_procedimento` — ON DELETE RESTRICT ON UPDATE CASCADE

## 14. `categoria_medicamento`

**Domínio:** Catálogos/Domínio · **Descrição:** Tabela de domínio das categorias terapêuticas (extraída na 3FN).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_categoria_medicamento` | `INT` | PK; NN; AI | Identificador da categoria. |
| `nome_categoria` | `VARCHAR(60)` | NN; UQ | Nome da categoria (único). |
| `descricao_categoria` | `VARCHAR(200)` | NULL | Descrição da categoria. |

**Índices adicionais:** `uq_categoria_nome` (UNIQUE: nome_categoria)

## 15. `medicamento`

**Domínio:** Catálogos/Domínio · **Descrição:** Catálogo de medicamentos com controle de estoque.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_medicamento` | `INT` | PK; NN; AI | Identificador do medicamento. |
| `nome_comercial` | `VARCHAR(100)` | NN; UQ | Nome comercial com apresentação (único). |
| `principio_ativo` | `VARCHAR(100)` | NN | Princípio(s) ativo(s) (descrição da fórmula). |
| `id_categoria_medicamento` | `INT` | FK → `categoria_medicamento.id_categoria_medicamento`; NN | Categoria; referencia `categoria_medicamento`. |
| `preco_unitario` | `DECIMAL(10,2)` | NN; CK `ck_med_preco`: `preco_unitario >= 0` | Preço unitário em R$ (≥ 0). |
| `estoque_atual` | `INT` | NN; DF `0`; CK `ck_med_estoque`: `estoque_atual >= 0` | Unidades em estoque (≥ 0). |

**Chaves estrangeiras:**

- `fk_med_categoria`: `id_categoria_medicamento` → `categoria_medicamento.id_categoria_medicamento` — ON DELETE RESTRICT ON UPDATE CASCADE

**Índices adicionais:** `uq_medicamento_nome` (UNIQUE: nome_comercial); `ix_medicamento_estoque` (estoque_atual)

## 16. `prescricao`

**Domínio:** Clínico · **Descrição:** Tabela associativa N:M entre consulta e medicamento (2FN). Registra o que foi prescrito.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `id_consulta` | `INT` | PK (composta); FK → `consulta.id_consulta`; NN | Consulta; parte da PK composta. |
| `id_medicamento` | `INT` | PK (composta); FK → `medicamento.id_medicamento`; NN | Medicamento; parte da PK composta. |
| `posologia` | `VARCHAR(150)` | NN | Forma de uso (dose e frequência). |
| `duracao_dias` | `INT` | NN; CK `ck_presc_duracao`: `duracao_dias > 0` | Duração do tratamento em dias (maior que zero). |
| `quantidade` | `INT` | NN; CK `ck_presc_qtd`: `quantidade > 0` | Unidades prescritas (maior que zero). |

**Chaves estrangeiras:**

- `fk_presc_consulta`: `id_consulta` → `consulta.id_consulta` — ON DELETE RESTRICT ON UPDATE CASCADE
- `fk_presc_medicamento`: `id_medicamento` → `medicamento.id_medicamento` — ON DELETE RESTRICT ON UPDATE CASCADE

## Resumo de integridade

- **16 tabelas**, **15 chaves estrangeiras**, 9 restrições CHECK nomeadas e 11 chaves UNIQUE.
- `ON DELETE CASCADE` apenas nas entidades fracas (`telefone_tutor`, `consulta_sintoma`); todas as demais FKs usam `ON DELETE RESTRICT`. Todas as FKs usam `ON UPDATE CASCADE`.
- Atributos derivados **não armazenados**: idade do animal (`data_nascimento`) e valor total da consulta (`SUM(quantidade * valor_cobrado)`), disponível na view `vw_consulta_valor_total`.
- Views de apoio (criadas em `sql/03_dql_queries.sql`): `vw_consulta_valor_total`, `vw_estoque_critico`, `vw_historico_clinico`.
