/* =====================================================================
   VetCare - Sistema de Gestão para Clínica Veterinária
   Arquivo : 01_ddl_schema.sql  (DDL)
   SGBD    : MySQL 8.0.16+ (cláusulas CHECK são aplicadas a partir desta versão)
   Autor   : Carlos Gabriel Novo - CST em Análise e Desenvolvimento de Sistemas
   Conteúdo: CREATE DATABASE + 16 tabelas em 3FN (15 chaves estrangeiras),
             PKs, FKs, UNIQUE, CHECK e índices de apoio.
   Ordem   : 01_ddl_schema -> 02_dml_seed -> 03_dql_queries -> 04_dml_updates_deletes
   Atenção : o script RECRIA o banco `vetcare` (DROP DATABASE IF EXISTS).
   ===================================================================== */

SET NAMES utf8mb4;

DROP DATABASE IF EXISTS vetcare;
CREATE DATABASE vetcare CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE vetcare;

-- ---------------------------------------------------------------------
-- Ordem de criação: tabelas independentes (domínio) -> dependentes
-- ---------------------------------------------------------------------

-- [Domínio] Elimina a dependência transitiva cep -> logradouro/bairro/cidade/uf (3FN)
CREATE TABLE endereco_cep (
  cep         CHAR(8)      NOT NULL,
  logradouro  VARCHAR(120) NOT NULL,
  bairro      VARCHAR(80)  NOT NULL,
  cidade      VARCHAR(80)  NOT NULL,
  uf          CHAR(2)      NOT NULL,
  PRIMARY KEY (cep)
) ENGINE=InnoDB;

-- [Cadastro] Tutor (responsável pelo animal). Endereço = FK para endereco_cep + número/complemento
CREATE TABLE tutor (
  id_tutor       INT          NOT NULL AUTO_INCREMENT,
  nome           VARCHAR(100) NOT NULL,
  cpf            CHAR(11)     NOT NULL,
  email          VARCHAR(120) NULL,
  data_cadastro  DATE         NOT NULL DEFAULT (CURRENT_DATE),
  cep            CHAR(8)      NOT NULL,
  numero         VARCHAR(10)  NOT NULL,
  complemento    VARCHAR(60)  NULL,
  PRIMARY KEY (id_tutor),
  UNIQUE KEY uq_tutor_cpf (cpf),
  UNIQUE KEY uq_tutor_email (email),
  KEY ix_tutor_nome (nome),
  CONSTRAINT ck_tutor_cpf_formato CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT fk_tutor_cep FOREIGN KEY (cep) REFERENCES endereco_cep (cep)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Cadastro] Entidade fraca (atributo multivalorado "telefones" resolvido na 1FN): PK composta
CREATE TABLE telefone_tutor (
  id_tutor         INT         NOT NULL,
  numero_telefone  VARCHAR(15) NOT NULL,
  tipo             ENUM('CELULAR','RESIDENCIAL','COMERCIAL') NOT NULL DEFAULT 'CELULAR',
  whatsapp         BOOLEAN     NOT NULL DEFAULT FALSE,
  PRIMARY KEY (id_tutor, numero_telefone),
  CONSTRAINT fk_telefone_tutor FOREIGN KEY (id_tutor) REFERENCES tutor (id_tutor)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Domínio] Espécie
CREATE TABLE especie (
  id_especie    INT         NOT NULL AUTO_INCREMENT,
  nome_especie  VARCHAR(50) NOT NULL,
  PRIMARY KEY (id_especie),
  UNIQUE KEY uq_especie_nome (nome_especie)
) ENGINE=InnoDB;

-- [Domínio] Raça: elimina a dependência transitiva id_raca -> id_especie dentro de animal
CREATE TABLE raca (
  id_raca     INT         NOT NULL AUTO_INCREMENT,
  id_especie  INT         NOT NULL,
  nome_raca   VARCHAR(80) NOT NULL,
  PRIMARY KEY (id_raca),
  UNIQUE KEY uq_raca_especie_nome (id_especie, nome_raca),
  CONSTRAINT fk_raca_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Cadastro] Animal. A idade é atributo DERIVADO (calculada de data_nascimento): não é armazenada
CREATE TABLE animal (
  id_animal        INT           NOT NULL AUTO_INCREMENT,
  id_tutor         INT           NOT NULL,
  id_raca          INT           NOT NULL,
  nome             VARCHAR(80)   NOT NULL,
  sexo             ENUM('M','F') NOT NULL,
  data_nascimento  DATE          NOT NULL,
  peso_kg          DECIMAL(5,2)  NOT NULL,
  microchip        CHAR(15)      NULL,
  ativo            BOOLEAN       NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_animal),
  UNIQUE KEY uq_animal_microchip (microchip),
  KEY ix_animal_nome (nome),
  CONSTRAINT ck_animal_peso CHECK (peso_kg > 0),
  CONSTRAINT fk_animal_tutor FOREIGN KEY (id_tutor) REFERENCES tutor (id_tutor)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_animal_raca FOREIGN KEY (id_raca) REFERENCES raca (id_raca)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Clínico] Prontuário: entidade fraca 1:1 identificada por animal (PK = FK)
CREATE TABLE prontuario (
  id_animal            INT  NOT NULL,
  data_abertura        DATE NOT NULL,
  alergias_conhecidas  TEXT NULL,
  observacoes_gerais   TEXT NULL,
  PRIMARY KEY (id_animal),
  CONSTRAINT fk_prontuario_animal FOREIGN KEY (id_animal) REFERENCES animal (id_animal)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Domínio] Especialidade veterinária
CREATE TABLE especialidade (
  id_especialidade    INT         NOT NULL AUTO_INCREMENT,
  nome_especialidade  VARCHAR(60) NOT NULL,
  PRIMARY KEY (id_especialidade),
  UNIQUE KEY uq_especialidade_nome (nome_especialidade)
) ENGINE=InnoDB;

-- [Cadastro] Veterinário (CRMV + UF únicos)
CREATE TABLE veterinario (
  id_veterinario    INT          NOT NULL AUTO_INCREMENT,
  nome              VARCHAR(100) NOT NULL,
  crmv              VARCHAR(10)  NOT NULL,
  uf_crmv           CHAR(2)      NOT NULL,
  email             VARCHAR(120) NOT NULL,
  id_especialidade  INT          NOT NULL,
  ativo             BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_veterinario),
  UNIQUE KEY uq_vet_crmv (crmv, uf_crmv),
  UNIQUE KEY uq_vet_email (email),
  CONSTRAINT fk_vet_especialidade FOREIGN KEY (id_especialidade) REFERENCES especialidade (id_especialidade)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Clínico] Consulta. valor_total é DERIVADO (SUM em consulta_procedimento): não é armazenado
CREATE TABLE consulta (
  id_consulta         INT          NOT NULL AUTO_INCREMENT,
  id_animal           INT          NOT NULL,
  id_veterinario      INT          NOT NULL,
  data_hora           DATETIME     NOT NULL,
  motivo              VARCHAR(200) NOT NULL,
  diagnostico         TEXT         NULL,
  status              ENUM('AGENDADA','REALIZADA','CANCELADA') NOT NULL DEFAULT 'AGENDADA',
  caminho_laudo_pdf   VARCHAR(255) NULL,
  PRIMARY KEY (id_consulta),
  KEY ix_consulta_data (data_hora),
  KEY ix_consulta_status_data (status, data_hora),
  CONSTRAINT fk_consulta_animal FOREIGN KEY (id_animal) REFERENCES animal (id_animal)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_consulta_vet FOREIGN KEY (id_veterinario) REFERENCES veterinario (id_veterinario)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Clínico] Entidade fraca (atributo multivalorado "sintomas" resolvido na 1FN): PK composta
CREATE TABLE consulta_sintoma (
  id_consulta        INT          NOT NULL,
  descricao_sintoma  VARCHAR(100) NOT NULL,
  PRIMARY KEY (id_consulta, descricao_sintoma),
  CONSTRAINT fk_sintoma_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Catálogo] Procedimento (serviços cobrados)
CREATE TABLE procedimento (
  id_procedimento    INT           NOT NULL AUTO_INCREMENT,
  nome_procedimento  VARCHAR(100)  NOT NULL,
  valor_padrao       DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_procedimento),
  UNIQUE KEY uq_procedimento_nome (nome_procedimento),
  CONSTRAINT ck_procedimento_valor CHECK (valor_padrao >= 0)
) ENGINE=InnoDB;

-- [Clínico] Associativa N:M (consulta x procedimento): PK composta;
-- a 2FN isola nome/valor_padrao em procedimento. valor_cobrado pode diferir de valor_padrao.
CREATE TABLE consulta_procedimento (
  id_consulta      INT           NOT NULL,
  id_procedimento  INT           NOT NULL,
  quantidade       INT           NOT NULL DEFAULT 1,
  valor_cobrado    DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_consulta, id_procedimento),
  CONSTRAINT ck_cp_quantidade CHECK (quantidade > 0),
  CONSTRAINT ck_cp_valor CHECK (valor_cobrado >= 0),
  CONSTRAINT fk_cp_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cp_procedimento FOREIGN KEY (id_procedimento) REFERENCES procedimento (id_procedimento)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Domínio] Categoria de medicamento: elimina id_categoria_medicamento -> nome/descrição da categoria
CREATE TABLE categoria_medicamento (
  id_categoria_medicamento  INT          NOT NULL AUTO_INCREMENT,
  nome_categoria            VARCHAR(60)  NOT NULL,
  descricao_categoria       VARCHAR(200) NULL,
  PRIMARY KEY (id_categoria_medicamento),
  UNIQUE KEY uq_categoria_nome (nome_categoria)
) ENGINE=InnoDB;

-- [Catálogo] Medicamento (com controle de estoque)
CREATE TABLE medicamento (
  id_medicamento            INT           NOT NULL AUTO_INCREMENT,
  nome_comercial            VARCHAR(100)  NOT NULL,
  principio_ativo           VARCHAR(100)  NOT NULL,
  id_categoria_medicamento  INT           NOT NULL,
  preco_unitario            DECIMAL(10,2) NOT NULL,
  estoque_atual             INT           NOT NULL DEFAULT 0,
  PRIMARY KEY (id_medicamento),
  UNIQUE KEY uq_medicamento_nome (nome_comercial),
  KEY ix_medicamento_estoque (estoque_atual),
  CONSTRAINT ck_med_preco CHECK (preco_unitario >= 0),
  CONSTRAINT ck_med_estoque CHECK (estoque_atual >= 0),
  CONSTRAINT fk_med_categoria FOREIGN KEY (id_categoria_medicamento)
    REFERENCES categoria_medicamento (id_categoria_medicamento)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- [Clínico] Associativa N:M (consulta x medicamento): PK composta
CREATE TABLE prescricao (
  id_consulta     INT          NOT NULL,
  id_medicamento  INT          NOT NULL,
  posologia       VARCHAR(150) NOT NULL,
  duracao_dias    INT          NOT NULL,
  quantidade      INT          NOT NULL,
  PRIMARY KEY (id_consulta, id_medicamento),
  CONSTRAINT ck_presc_duracao CHECK (duracao_dias > 0),
  CONSTRAINT ck_presc_qtd CHECK (quantidade > 0),
  CONSTRAINT fk_presc_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_presc_medicamento FOREIGN KEY (id_medicamento) REFERENCES medicamento (id_medicamento)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
