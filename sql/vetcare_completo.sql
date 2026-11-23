/* =====================================================================
   VetCare - Sistema de Gestão para Clínica Veterinária
   Arquivo : vetcare_completo.sql  (script consolidado e autoexecutável)
   SGBD    : MySQL 8.0.16+  |  Autor: Carlos Gabriel Novo
   Conteúdo: concatenação ordenada de sql/01 + 02 + 03 + 04.
             1) DDL  2) INSERT  3) SELECT/VIEWs  4) UPDATE/DELETE
   Uso     : mysql -u root -p < vetcare_completo.sql
             (ou File > Open SQL Script no MySQL Workbench / DB-Fiddle).
   Atenção : RECRIA o banco `vetcare` (DROP DATABASE IF EXISTS) e, ao final,
             deixa os dados no estado pós-UPDATE/DELETE. Para um banco
             "limpo" (somente schema + seed) execute apenas 01 e 02.
   Dados   : todos FICTÍCIOS.
   Gerado a partir dos arquivos modulares (01 a 04); não edite à mão.
   ===================================================================== */


-- #####################################################################
-- 1) DDL - schema   (origem: sql/01_ddl_schema.sql)
-- #####################################################################

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


-- #####################################################################
-- 2) DML - povoamento (INSERT)   (origem: sql/02_dml_seed.sql)
-- #####################################################################

SET NAMES utf8mb4;
USE vetcare;

-- ---------------------------------------------------------------------
-- 1) Tabelas independentes (sem FK)
-- ---------------------------------------------------------------------
INSERT INTO endereco_cep (cep, logradouro, bairro, cidade, uf) VALUES
('01310100', 'Avenida Paulista',              'Bela Vista', 'São Paulo',      'SP'),
('04538133', 'Avenida Brigadeiro Faria Lima', 'Itaim Bibi', 'São Paulo',      'SP'),
('05422010', 'Rua dos Pinheiros',             'Pinheiros',  'São Paulo',      'SP'),
('09015200', 'Rua Oliveira Lima',             'Centro',     'Santo André',    'SP'),
('13010000', 'Rua Barão de Jaguara',          'Centro',     'Campinas',       'SP'),
('20040020', 'Rua da Assembleia',             'Centro',     'Rio de Janeiro', 'RJ'),
('30130010', 'Avenida Afonso Pena',           'Centro',     'Belo Horizonte', 'MG');

INSERT INTO especie (nome_especie) VALUES ('Cão'), ('Gato'), ('Coelho');   -- 1, 2, 3

INSERT INTO especialidade (nome_especialidade) VALUES
('Clínica Geral'), ('Dermatologia'), ('Cardiologia'), ('Ortopedia');       -- 1..4

INSERT INTO procedimento (nome_procedimento, valor_padrao) VALUES
('Consulta clínica geral',                   120.00),  -- 1
('Vacina V10 (múltipla canina)',              95.00),  -- 2
('Vacina antirrábica',                        70.00),  -- 3
('Hemograma completo',                        85.00),  -- 4
('Radiografia simples',                      180.00),  -- 5
('Ultrassonografia abdominal',               260.00),  -- 6
('Limpeza de tártaro (profilaxia dentária)', 420.00),  -- 7
('Ecocardiograma',                           350.00),  -- 8
('Vermifugação',                              45.00);  -- 9

INSERT INTO categoria_medicamento (nome_categoria, descricao_categoria) VALUES
('Antibiótico',                    'Combate infecções bacterianas'),            -- 1
('Analgésico e anti-inflamatório', 'Reduz dor, inflamação e febre'),            -- 2
('Antiparasitário',                'Controle de pulgas, carrapatos e vermes'),  -- 3
('Antialérgico',                   'Trata alergias e afecções de pele'),        -- 4
('Cardiológico',                   'Controle de doenças cardíacas');            -- 5

-- ---------------------------------------------------------------------
-- 2) Dependentes de primeiro nível
-- ---------------------------------------------------------------------
INSERT INTO raca (id_especie, nome_raca) VALUES
(1, 'Labrador Retriever'),       -- id_raca 1
(1, 'Shih Tzu'),                 -- 2
(1, 'Golden Retriever'),         -- 3
(1, 'Sem Raça Definida (SRD)'),  -- 4
(2, 'Siamês'),                   -- 5
(2, 'Persa'),                    -- 6
(2, 'Sem Raça Definida (SRD)'),  -- 7
(3, 'Mini Lop');                 -- 8

INSERT INTO tutor (nome, cpf, email, data_cadastro, cep, numero, complemento) VALUES
('Mariana Souza Lima',     '39053344705', 'mariana.lima@example.com',   '2024-02-10', '01310100', '1578', 'Apto 52'),  -- 1
('Carlos Eduardo Ramos',   '11144477735', 'carlos.ramos@example.com',   '2024-03-05', '05422010', '320',  NULL),       -- 2
('Fernanda Alves Costa',   '52998224725', 'fernanda.costa@example.com', '2024-04-18', '04538133', '4100', 'Sala 12'),   -- 3
('João Pedro Martins',     '45317828791', 'joao.martins@example.com',   '2024-06-22', '09015200', '85',   NULL),       -- 4
('Patrícia Gomes Rocha',   '86288366757', 'patricia.rocha@example.com', '2024-08-30', '13010000', '910',  'Casa 2'),   -- 5
('Ricardo Teixeira Prado', '15350946056', 'ricardo.prado@example.com',  '2025-01-14', '20040020', '45',   'Cj 301'),   -- 6
('Luciana Barbosa Nunes',  '71428793860', 'luciana.nunes@example.com',  '2025-03-02', '30130010', '2200', NULL),       -- 7
('Bruno Henrique Dias',    '93541134780', 'bruno.dias@example.com',     '2025-05-19', '05422010', '77',   NULL);       -- 8 (sem animais)

INSERT INTO veterinario (nome, crmv, uf_crmv, email, id_especialidade, ativo) VALUES
('Dra. Helena Duarte',  '12345', 'SP', 'helena.duarte@vetcare.example',   1, TRUE),  -- 1
('Dr. Rafael Monteiro', '23456', 'SP', 'rafael.monteiro@vetcare.example', 2, TRUE),  -- 2
('Dra. Camila Ferraz',  '34567', 'SP', 'camila.ferraz@vetcare.example',   3, TRUE),  -- 3
('Dr. André Siqueira',  '45678', 'SP', 'andre.siqueira@vetcare.example',  4, TRUE);  -- 4

INSERT INTO medicamento (nome_comercial, principio_ativo, id_categoria_medicamento, preco_unitario, estoque_atual) VALUES
('Amoxicilina 250mg',       'Amoxicilina',                        1,   1.80, 400),  -- 1
('Meloxicam 1mg',           'Meloxicam',                          2,   2.50, 300),  -- 2
('Prednisolona 20mg',       'Prednisolona',                       2,   3.20, 150),  -- 3
('Drontal Plus',            'Praziquantel + Pamoato de Pirantel', 3,   6.90, 120),  -- 4
('Bravecto 250mg',          'Fluralaner',                         3, 115.00,  25),  -- 5 (estoque baixo)
('Apoquel 5,4mg',           'Oclacitinib',                        4,   9.80, 200),  -- 6
('Enalapril 10mg',          'Maleato de Enalapril',               5,   2.10, 180),  -- 7
('Cefalexina 500mg',        'Cefalexina',                         1,   2.90, 260),  -- 8
('Dipirona 500mg/mL gotas', 'Dipirona sódica',                    2,   0.90,   0);  -- 9 (descontinuado)

-- ---------------------------------------------------------------------
-- 3) Dependentes de segundo nível
-- ---------------------------------------------------------------------
INSERT INTO telefone_tutor (id_tutor, numero_telefone, tipo, whatsapp) VALUES
(1, '11987654321', 'CELULAR',     TRUE),
(1, '1133221100',  'RESIDENCIAL', FALSE),
(2, '11976543210', 'CELULAR',     TRUE),
(3, '11965432109', 'CELULAR',     TRUE),
(3, '1135554444',  'COMERCIAL',   FALSE),
(4, '11954321098', 'CELULAR',     TRUE),
(5, '19943210987', 'CELULAR',     TRUE),
(6, '21932109876', 'CELULAR',     TRUE),
(6, '2122223333',  'COMERCIAL',   FALSE),
(7, '31921098765', 'CELULAR',     TRUE),
(8, '11910987654', 'CELULAR',     FALSE);

INSERT INTO animal (id_tutor, id_raca, nome, sexo, data_nascimento, peso_kg, microchip, ativo) VALUES
(1, 1, 'Thor',     'M', '2019-05-12', 32.40, '985112345678901', TRUE),   -- 1
(1, 5, 'Mel',      'F', '2021-09-03',  4.20, '985112345678902', TRUE),   -- 2
(2, 2, 'Luna',     'F', '2020-01-25',  6.80, '985112345678903', TRUE),   -- 3
(3, 4, 'Bidu',     'M', '2018-11-30', 14.50, NULL,              TRUE),   -- 4
(3, 6, 'Garfield', 'M', '2022-04-17',  5.90, '985112345678905', TRUE),   -- 5
(4, 3, 'Max',      'M', '2017-07-08', 30.10, '985112345678906', TRUE),   -- 6
(5, 7, 'Nina',     'F', '2023-02-14',  3.80, NULL,              TRUE),   -- 7
(5, 1, 'Rex',      'M', '2016-10-21', 29.00, '985112345678908', FALSE),  -- 8 (inativo)
(6, 8, 'Pipoca',   'F', '2022-12-01',  1.90, NULL,              TRUE),   -- 9
(7, 2, 'Mia',      'F', '2021-06-09',  7.10, '985112345678910', TRUE),   -- 10
(7, 4, 'Toby',     'M', '2020-03-15', 12.30, '985112345678911', TRUE);   -- 11

-- Prontuário (1:1 com animal; PK = FK)
INSERT INTO prontuario (id_animal, data_abertura, alergias_conhecidas, observacoes_gerais) VALUES
(1,  '2024-02-10', NULL,                     'Acompanhamento de peso; vacinação em dia.'),
(2,  '2024-02-10', 'Dipirona',               'Sensível a manuseio; usar contenção suave.'),
(3,  '2024-03-05', 'Picada de pulga (DAPP)', 'Histórico de dermatite alérgica.'),
(4,  '2024-04-18', NULL,                     'Displasia coxofemoral em acompanhamento.'),
(5,  '2024-04-18', NULL,                     'Pelagem longa; escovação semanal recomendada.'),
(6,  '2024-06-22', NULL,                     'Cardiopata em tratamento contínuo.'),
(7,  '2024-08-30', NULL,                     'Filhote resgatado; protocolo vacinal completo.'),
(8,  '2024-08-30', NULL,                     'Paciente inativo (transferido de clínica).'),
(9,  '2025-01-14', NULL,                     'Dieta à base de feno e ração específica.'),
(10, '2025-03-02', 'Sulfonamidas',           'Evitar sulfas; protocolo alternativo para infecções.'),
(11, '2025-03-02', NULL,                     'Adotado; sem intercorrências.');

-- ---------------------------------------------------------------------
-- 4) Consultas (dependem de animal e veterinário)
--    Status: 15 REALIZADA, 1 CANCELADA (16) e 3 AGENDADA (17, 18, 19)
-- ---------------------------------------------------------------------
INSERT INTO consulta (id_animal, id_veterinario, data_hora, motivo, diagnostico, status, caminho_laudo_pdf) VALUES
(1,  1, '2025-09-10 09:00:00', 'Check-up anual e vacinação',        'Animal saudável; vacinas atualizadas.', 'REALIZADA', NULL),                                            -- 1
(2,  1, '2025-09-15 10:30:00', 'Vômito e apatia',                   'Gastroenterite leve.',                  'REALIZADA', NULL),                                            -- 2
(3,  2, '2025-10-02 14:00:00', 'Coceira intensa e queda de pelos',  'Dermatite atópica.',                    'REALIZADA', 'laudos/2025/consulta_0003_laudo.pdf'),           -- 3
(4,  4, '2025-10-20 11:00:00', 'Claudicação em membro posterior',   'Displasia coxofemoral grau leve.',      'REALIZADA', 'laudos/2025/consulta_0004_radiografia.pdf'),     -- 4
(6,  3, '2025-11-05 15:30:00', 'Tosse persistente e cansaço',       'Cardiomiopatia dilatada inicial.',      'REALIZADA', 'laudos/2025/consulta_0005_eco.pdf'),             -- 5
(5,  1, '2025-11-18 16:00:00', 'Vacinação e vermifugação',          'Sem alterações.',                       'REALIZADA', NULL),                                            -- 6
(7,  1, '2025-12-09 09:30:00', 'Primeira consulta de filhote',      'Filhote saudável.',                     'REALIZADA', NULL),                                            -- 7
(9,  1, '2026-01-14 10:00:00', 'Perda de apetite',                  'Má oclusão dentária.',                  'REALIZADA', NULL),                                            -- 8
(10, 2, '2026-02-03 13:30:00', 'Coceira e secreção no ouvido',      'Otite externa.',                        'REALIZADA', 'laudos/2026/consulta_0009_laudo.pdf'),           -- 9
(1,  1, '2026-03-12 09:00:00', 'Reforço vacinal',                   'Sem alterações.',                       'REALIZADA', NULL),                                            -- 10
(11, 1, '2026-04-22 11:30:00', 'Diarreia há 3 dias',                'Parasitose intestinal.',                'REALIZADA', NULL),                                            -- 11
(4,  4, '2026-05-14 14:30:00', 'Retorno ortopédico',                'Evolução favorável.',                   'REALIZADA', NULL),                                            -- 12
(6,  3, '2026-06-09 15:00:00', 'Retorno cardiológico',              'Quadro estável com medicação.',         'REALIZADA', 'laudos/2026/consulta_0013_eco.pdf'),             -- 13
(3,  2, '2026-08-25 10:00:00', 'Recidiva de coceira',               'Dermatite alérgica controlada.',        'REALIZADA', NULL),                                            -- 14
(2,  1, '2026-09-30 09:30:00', 'Check-up semestral',                'Sem alterações.',                       'REALIZADA', NULL),                                            -- 15
(8,  4, '2026-10-06 16:30:00', 'Avaliação de claudicação',          NULL,                                    'CANCELADA', NULL),                                            -- 16 (cancelada)
(5,  1, '2026-11-20 09:00:00', 'Retorno por gastrite',              NULL,                                    'AGENDADA',  NULL),                                            -- 17 (será atualizada no 04)
(1,  3, '2026-11-26 14:00:00', 'Avaliação cardiológica preventiva', NULL,                                    'AGENDADA',  NULL),                                            -- 18
(9,  1, '2026-12-02 10:00:00', 'Vacinação anual',                   NULL,                                    'AGENDADA',  NULL);                                            -- 19

-- Sintomas (multivalorado -> tabela fraca)
INSERT INTO consulta_sintoma (id_consulta, descricao_sintoma) VALUES
(2,  'Vômito'), (2,  'Apatia'), (2,  'Inapetência'),
(3,  'Prurido intenso'), (3, 'Queda de pelos'), (3, 'Vermelhidão na pele'),
(4,  'Claudicação'), (4, 'Dor ao levantar'),
(5,  'Tosse'), (5, 'Cansaço fácil'), (5, 'Intolerância a exercício'),
(8,  'Perda de apetite'), (8, 'Mau hálito'),
(9,  'Coceira nas orelhas'), (9, 'Secreção no ouvido'),
(11, 'Diarreia'), (11, 'Vômito'),
(14, 'Prurido'), (14, 'Lambedura excessiva'),
(16, 'Mancar'),
(17, 'Vômito ocasional');

-- Procedimentos realizados (N:M) - valor_cobrado pode diferir do valor_padrao
INSERT INTO consulta_procedimento (id_consulta, id_procedimento, quantidade, valor_cobrado) VALUES
(1, 1, 1, 120.00), (1, 2, 1,  90.00), (1, 3, 1,  70.00),
(2, 1, 1, 120.00), (2, 4, 1,  85.00),
(3, 1, 1, 120.00), (3, 4, 1,  85.00),
(4, 1, 1, 120.00), (4, 5, 2, 180.00),
(5, 1, 1, 120.00), (5, 8, 1, 350.00), (5, 5, 1, 180.00),
(6, 1, 1, 120.00), (6, 3, 1,  70.00), (6, 9, 1,  40.00),
(7, 1, 1, 120.00), (7, 9, 1,  45.00),
(8, 1, 1, 120.00), (8, 7, 1, 420.00),
(9, 1, 1, 120.00),
(10, 2, 1, 95.00), (10, 3, 1, 70.00),
(11, 1, 1, 120.00), (11, 4, 1, 85.00), (11, 9, 1, 45.00),
(12, 1, 1, 120.00), (12, 5, 1, 180.00),
(13, 1, 1, 120.00), (13, 8, 1, 350.00),
(14, 1, 1, 120.00),
(15, 1, 1, 120.00), (15, 4, 1,  85.00),
(16, 1, 1,   0.00),
(17, 1, 1, 120.00),
(18, 1, 1, 120.00), (18, 8, 1, 350.00),
(19, 2, 1,  95.00);

-- Prescrições (N:M)
INSERT INTO prescricao (id_consulta, id_medicamento, posologia, duracao_dias, quantidade) VALUES
(2,  1, '1 comprimido a cada 12 horas',                      5,  10),
(3,  6, '1 comprimido a cada 12 horas',                     14,  28),
(3,  3, '1/2 comprimido a cada 24 horas',                    5,   3),
(4,  2, '1 comprimido a cada 24 horas',                     10,  10),
(5,  7, '1 comprimido a cada 12 horas',                     30,  60),
(6,  4, '1 comprimido para cada 10 kg, dose única',          1,   1),
(7,  4, '1/2 comprimido, dose única',                        1,   1),
(9,  8, '1 comprimido a cada 12 horas',                     10,  20),
(9,  3, '1/2 comprimido a cada 24 horas',                    5,   3),
(11, 4, '1 comprimido para cada 10 kg, repetir em 15 dias', 15,   2),
(12, 2, '1/2 comprimido a cada 24 horas',                    7,   4),
(13, 7, '1 comprimido a cada 12 horas',                     60, 120),
(14, 6, '1 comprimido a cada 12 horas',                      7,  14);

-- ---------------------------------------------------------------------
-- Conferência da carga (linhas por tabela)
-- Esperado: 7, 8, 11, 3, 8, 11, 11, 4, 4, 19, 21, 9, 37, 5, 9, 13
-- ---------------------------------------------------------------------
SELECT 'endereco_cep' AS tabela, COUNT(*) AS linhas FROM endereco_cep
UNION ALL SELECT 'tutor',                 COUNT(*) FROM tutor
UNION ALL SELECT 'telefone_tutor',        COUNT(*) FROM telefone_tutor
UNION ALL SELECT 'especie',               COUNT(*) FROM especie
UNION ALL SELECT 'raca',                  COUNT(*) FROM raca
UNION ALL SELECT 'animal',                COUNT(*) FROM animal
UNION ALL SELECT 'prontuario',            COUNT(*) FROM prontuario
UNION ALL SELECT 'especialidade',         COUNT(*) FROM especialidade
UNION ALL SELECT 'veterinario',           COUNT(*) FROM veterinario
UNION ALL SELECT 'consulta',              COUNT(*) FROM consulta
UNION ALL SELECT 'consulta_sintoma',      COUNT(*) FROM consulta_sintoma
UNION ALL SELECT 'procedimento',          COUNT(*) FROM procedimento
UNION ALL SELECT 'consulta_procedimento', COUNT(*) FROM consulta_procedimento
UNION ALL SELECT 'categoria_medicamento', COUNT(*) FROM categoria_medicamento
UNION ALL SELECT 'medicamento',           COUNT(*) FROM medicamento
UNION ALL SELECT 'prescricao',            COUNT(*) FROM prescricao;


-- #####################################################################
-- 3) DQL - views e consultas analíticas   (origem: sql/03_dql_queries.sql)
-- #####################################################################

SET NAMES utf8mb4;
USE vetcare;

-- =====================================================================
-- PARTE A - VIEWS (relatórios reutilizáveis)
-- =====================================================================

-- A1: valor_total (atributo DERIVADO) de cada consulta. LEFT JOIN mantém consultas sem procedimento (total 0).
DROP VIEW IF EXISTS vw_consulta_valor_total;
CREATE VIEW vw_consulta_valor_total AS
SELECT c.id_consulta,
       c.data_hora,
       c.status,
       a.nome                                        AS animal,
       v.nome                                        AS veterinario,
       COUNT(cp.id_procedimento)                     AS qtd_procedimentos,
       COALESCE(SUM(cp.quantidade * cp.valor_cobrado), 0) AS valor_total
FROM consulta c
INNER JOIN animal      a ON a.id_animal      = c.id_animal
INNER JOIN veterinario v ON v.id_veterinario = c.id_veterinario
LEFT  JOIN consulta_procedimento cp ON cp.id_consulta = c.id_consulta
GROUP BY c.id_consulta, c.data_hora, c.status, a.nome, v.nome;

-- A2: medicamentos com estoque crítico (menos de 50 unidades), com categoria
DROP VIEW IF EXISTS vw_estoque_critico;
CREATE VIEW vw_estoque_critico AS
SELECT m.id_medicamento,
       m.nome_comercial,
       cm.nome_categoria,
       m.estoque_atual,
       m.preco_unitario
FROM medicamento m
INNER JOIN categoria_medicamento cm ON cm.id_categoria_medicamento = m.id_categoria_medicamento
WHERE m.estoque_atual < 50;

-- A3: histórico clínico unificado (animal, tutor, espécie/raça, veterinário e consulta)
DROP VIEW IF EXISTS vw_historico_clinico;
CREATE VIEW vw_historico_clinico AS
SELECT a.id_animal,
       a.nome                AS animal,
       e.nome_especie        AS especie,
       r.nome_raca           AS raca,
       t.nome                AS tutor,
       c.id_consulta,
       c.data_hora,
       v.nome                AS veterinario,
       c.motivo,
       c.diagnostico,
       c.status
FROM animal a
INNER JOIN raca        r ON r.id_raca        = a.id_raca
INNER JOIN especie     e ON e.id_especie     = r.id_especie
INNER JOIN tutor       t ON t.id_tutor       = a.id_tutor
INNER JOIN consulta    c ON c.id_animal      = a.id_animal
INNER JOIN veterinario v ON v.id_veterinario = c.id_veterinario;

-- =====================================================================
-- PARTE B - CONSULTAS
-- =====================================================================

-- Q1 (INNER JOIN x6 + WHERE + ORDER BY + LIMIT): últimas 5 consultas REALIZADAS com
--    animal, espécie/raça, tutor, veterinário e idade (atributo derivado) em anos
SELECT c.id_consulta,
       c.data_hora,
       a.nome                                            AS animal,
       e.nome_especie                                    AS especie,
       r.nome_raca                                       AS raca,
       TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade_anos,
       t.nome                                            AS tutor,
       v.nome                                            AS veterinario,
       c.motivo
FROM consulta c
INNER JOIN animal      a ON a.id_animal      = c.id_animal
INNER JOIN raca        r ON r.id_raca        = a.id_raca
INNER JOIN especie     e ON e.id_especie     = r.id_especie
INNER JOIN tutor       t ON t.id_tutor       = a.id_tutor
INNER JOIN veterinario v ON v.id_veterinario = c.id_veterinario
WHERE c.status = 'REALIZADA'
ORDER BY c.data_hora DESC
LIMIT 5;

-- Q2 (JOIN + SUM + GROUP BY + HAVING + ORDER BY + LIMIT): valor_total por consulta;
--    somente consultas realizadas com total acima de R$ 250,00 (esperado: 5 linhas; maior = consulta 5, R$ 650,00)
SELECT c.id_consulta,
       a.nome                                AS animal,
       DATE(c.data_hora)                     AS data_consulta,
       COUNT(cp.id_procedimento)             AS qtd_procedimentos,
       SUM(cp.quantidade * cp.valor_cobrado) AS valor_total
FROM consulta c
INNER JOIN animal                a  ON a.id_animal    = c.id_animal
INNER JOIN consulta_procedimento cp ON cp.id_consulta = c.id_consulta
WHERE c.status = 'REALIZADA'
GROUP BY c.id_consulta, a.nome, DATE(c.data_hora)
HAVING SUM(cp.quantidade * cp.valor_cobrado) > 250
ORDER BY valor_total DESC
LIMIT 5;

-- Q3 (LEFT JOIN + COUNT + GROUP BY + ORDER BY): animais por tutor, incluindo tutores sem animal
--    (esperado: o tutor 8, Bruno Henrique Dias, aparece com 0)
SELECT t.id_tutor,
       t.nome             AS tutor,
       ec.cidade,
       COUNT(a.id_animal) AS qtd_animais
FROM tutor t
INNER JOIN endereco_cep ec ON ec.cep = t.cep
LEFT  JOIN animal       a  ON a.id_tutor = t.id_tutor
GROUP BY t.id_tutor, t.nome, ec.cidade
ORDER BY qtd_animais DESC, t.nome
LIMIT 10;

-- Q4 (JOIN N:M + COUNT + SUM + AVG + GROUP BY + HAVING): categorias de medicamento mais prescritas
--    (somente categorias com 3 ou mais prescrições)
SELECT cm.nome_categoria,
       COUNT(*)                     AS total_prescricoes,
       SUM(p.quantidade)            AS unidades_prescritas,
       ROUND(AVG(p.duracao_dias),1) AS duracao_media_dias
FROM prescricao p
INNER JOIN medicamento           m  ON m.id_medicamento = p.id_medicamento
INNER JOIN categoria_medicamento cm ON cm.id_categoria_medicamento = m.id_categoria_medicamento
GROUP BY cm.nome_categoria
HAVING COUNT(*) >= 3
ORDER BY total_prescricoes DESC, cm.nome_categoria
LIMIT 5;

-- Q5 (LEFT JOIN + múltiplas agregações + intervalo de datas): produtividade por veterinário em 2026
--    (consultas realizadas e receita de procedimentos)
SELECT v.nome                                             AS veterinario,
       esp.nome_especialidade                             AS especialidade,
       COUNT(DISTINCT c.id_consulta)                      AS consultas_realizadas,
       COALESCE(SUM(cp.quantidade * cp.valor_cobrado), 0) AS receita_procedimentos
FROM veterinario v
INNER JOIN especialidade esp ON esp.id_especialidade = v.id_especialidade
LEFT  JOIN consulta c  ON c.id_veterinario = v.id_veterinario
                      AND c.status = 'REALIZADA'
                      AND c.data_hora >= '2026-01-01' AND c.data_hora < '2027-01-01'
LEFT  JOIN consulta_procedimento cp ON cp.id_consulta = c.id_consulta
GROUP BY v.id_veterinario, v.nome, esp.nome_especialidade
ORDER BY receita_procedimentos DESC
LIMIT 5;

-- Q6 (VIEW + AVG + GROUP BY + HAVING): ticket médio por veterinário nas consultas realizadas
--    (somente veterinários com ao menos 2 consultas realizadas)
SELECT veterinario,
       COUNT(*)                   AS consultas,
       ROUND(AVG(valor_total), 2) AS ticket_medio,
       MAX(valor_total)           AS maior_consulta
FROM vw_consulta_valor_total
WHERE status = 'REALIZADA'
GROUP BY veterinario
HAVING COUNT(*) >= 2
ORDER BY ticket_medio DESC;

-- Q7 (função de data + SUM + GROUP BY): faturamento mensal de procedimentos (consultas realizadas)
SELECT DATE_FORMAT(c.data_hora, '%Y-%m')      AS mes,
       COUNT(DISTINCT c.id_consulta)          AS consultas,
       SUM(cp.quantidade * cp.valor_cobrado)  AS faturamento
FROM consulta c
INNER JOIN consulta_procedimento cp ON cp.id_consulta = c.id_consulta
WHERE c.status = 'REALIZADA'
GROUP BY DATE_FORMAT(c.data_hora, '%Y-%m')
ORDER BY mes;

-- Q8 (anti-join com LEFT JOIN ... IS NULL): pacientes que nunca tiveram consulta REALIZADA
--    (esperado: Rex, animal inativo cuja única consulta foi cancelada)
SELECT a.id_animal, a.nome AS animal, a.ativo, t.nome AS tutor
FROM animal a
INNER JOIN tutor t ON t.id_tutor = a.id_tutor
LEFT  JOIN consulta c ON c.id_animal = a.id_animal AND c.status = 'REALIZADA'
WHERE c.id_consulta IS NULL
ORDER BY a.nome;

-- Q9 (JOIN + GROUP BY + HAVING): sintomas mais frequentes nos atendimentos (ocorrem em 2+ consultas)
SELECT s.descricao_sintoma,
       COUNT(*) AS ocorrencias
FROM consulta_sintoma s
INNER JOIN consulta c ON c.id_consulta = s.id_consulta
GROUP BY s.descricao_sintoma
HAVING COUNT(*) >= 2
ORDER BY ocorrencias DESC, s.descricao_sintoma;

-- Q10 (JOIN em cadeia + SUM/COUNT): receita e volume por espécie atendida
SELECT e.nome_especie                          AS especie,
       COUNT(DISTINCT c.id_consulta)           AS consultas_realizadas,
       COUNT(DISTINCT a.id_animal)             AS animais_atendidos,
       SUM(cp.quantidade * cp.valor_cobrado)   AS receita
FROM consulta c
INNER JOIN animal                a  ON a.id_animal    = c.id_animal
INNER JOIN raca                  r  ON r.id_raca      = a.id_raca
INNER JOIN especie               e  ON e.id_especie   = r.id_especie
INNER JOIN consulta_procedimento cp ON cp.id_consulta = c.id_consulta
WHERE c.status = 'REALIZADA'
GROUP BY e.nome_especie
ORDER BY receita DESC;

-- Q11 (VIEW + subconsulta escalar): consultas realizadas acima do ticket médio geral da clínica
SELECT id_consulta, data_hora, animal, veterinario, valor_total
FROM vw_consulta_valor_total
WHERE status = 'REALIZADA'
  AND valor_total > (SELECT AVG(valor_total) FROM vw_consulta_valor_total WHERE status = 'REALIZADA')
ORDER BY valor_total DESC;

-- Q12 (VIEW de estoque + anti-join): medicamentos com estoque crítico e se já foram prescritos
--    (esperado: Bravecto 25 un. nunca prescrito; Dipirona 0 un. nunca prescrita)
SELECT ec.nome_comercial,
       ec.nome_categoria,
       ec.estoque_atual,
       CASE WHEN COUNT(p.id_consulta) = 0 THEN 'Nunca prescrito' ELSE 'Já prescrito' END AS situacao
FROM vw_estoque_critico ec
LEFT JOIN prescricao p ON p.id_medicamento = ec.id_medicamento
GROUP BY ec.id_medicamento, ec.nome_comercial, ec.nome_categoria, ec.estoque_atual
ORDER BY ec.estoque_atual;

-- Q13 (VIEW de histórico): linha do tempo clínica de um animal (Thor, id 1)
SELECT id_consulta, data_hora, veterinario, motivo, diagnostico, status
FROM vw_historico_clinico
WHERE id_animal = 1
ORDER BY data_hora;


-- #####################################################################
-- 4) DML - UPDATE e DELETE com transações   (origem: sql/04_dml_updates_deletes.sql)
-- #####################################################################

SET NAMES utf8mb4;
USE vetcare;

-- =====================================================================
-- PARTE A - UPDATEs
-- =====================================================================

-- U1: reajuste de 5% nas vacinas (procedimentos 2 e 3). Preços já cobrados em consultas não mudam.
SELECT id_procedimento, nome_procedimento, valor_padrao FROM procedimento WHERE id_procedimento IN (2, 3);
START TRANSACTION;
UPDATE procedimento
   SET valor_padrao = ROUND(valor_padrao * 1.05, 2)
 WHERE id_procedimento IN (2, 3);
SELECT id_procedimento, nome_procedimento, valor_padrao FROM procedimento WHERE id_procedimento IN (2, 3);
COMMIT;

-- U2: consulta agendada que já ocorreu passa a REALIZADA, com diagnóstico (somente se ainda AGENDADA)
SELECT id_consulta, status, diagnostico FROM consulta WHERE id_consulta = 17;
START TRANSACTION;
UPDATE consulta
   SET status = 'REALIZADA',
       diagnostico = 'Gastrite leve em resolução; manter dieta gastrointestinal por 7 dias.'
 WHERE id_consulta = 17
   AND status = 'AGENDADA';
SELECT id_consulta, status, diagnostico FROM consulta WHERE id_consulta = 17;
COMMIT;

-- U3: baixa de estoque pela prescrição da consulta 14 (Apoquel, 14 unidades).
--     A condição "estoque_atual >= quantidade" impede estoque negativo (e o CHECK ck_med_estoque reforça).
SELECT id_medicamento, nome_comercial, estoque_atual FROM medicamento WHERE id_medicamento = 6;
START TRANSACTION;
UPDATE medicamento
   SET estoque_atual = estoque_atual
         - (SELECT p.quantidade FROM prescricao p WHERE p.id_consulta = 14 AND p.id_medicamento = 6)
 WHERE id_medicamento = 6
   AND estoque_atual >= (SELECT p.quantidade FROM prescricao p WHERE p.id_consulta = 14 AND p.id_medicamento = 6);
SELECT id_medicamento, nome_comercial, estoque_atual FROM medicamento WHERE id_medicamento = 6;   -- esperado: 186
COMMIT;

-- U4: mudança de endereço do tutor (o novo CEP precisa existir em endereco_cep: integridade referencial)
SELECT id_tutor, nome, cep, numero, complemento FROM tutor WHERE id_tutor = 4;
START TRANSACTION;
UPDATE tutor
   SET cep = '04538133', numero = '250', complemento = 'Apto 31'
 WHERE id_tutor = 4;
SELECT id_tutor, nome, cep, numero, complemento FROM tutor WHERE id_tutor = 4;
COMMIT;

-- U5: atualização do peso do animal na última pesagem
SELECT id_animal, nome, peso_kg FROM animal WHERE id_animal = 1;
START TRANSACTION;
UPDATE animal SET peso_kg = 33.10 WHERE id_animal = 1;
SELECT id_animal, nome, peso_kg FROM animal WHERE id_animal = 1;
COMMIT;

-- U6 (ROLLBACK): simulação de erro operacional desfeita. Desativa TODOS os veterinários de uma
--     especialidade por engano, confere o impacto e desfaz a operação.
START TRANSACTION;
UPDATE veterinario SET ativo = FALSE WHERE id_especialidade = 1;
SELECT id_veterinario, nome, ativo FROM veterinario WHERE id_especialidade = 1;   -- impacto: ativo = 0
ROLLBACK;
SELECT id_veterinario, nome, ativo FROM veterinario WHERE id_especialidade = 1;   -- restaurado: ativo = 1

-- =====================================================================
-- PARTE B - DELETEs (ordem filha -> pai)
-- =====================================================================

-- D1: remove um sintoma registrado por engano (tabela filha de consulta, chave composta)
SELECT * FROM consulta_sintoma WHERE id_consulta = 11;
START TRANSACTION;
DELETE FROM consulta_sintoma
 WHERE id_consulta = 11
   AND descricao_sintoma = 'Vômito';
SELECT * FROM consulta_sintoma WHERE id_consulta = 11;
COMMIT;

-- D2: remove uma prescrição lançada por engano (tabela associativa; nada depende dela)
SELECT * FROM prescricao WHERE id_consulta = 9;
START TRANSACTION;
DELETE FROM prescricao
 WHERE id_consulta = 9
   AND id_medicamento = 3;
SELECT * FROM prescricao WHERE id_consulta = 9;
COMMIT;

-- D3: exclui a consulta CANCELADA 16 respeitando a ordem filha -> pai
--     (consulta_procedimento usa RESTRICT e é removida antes; consulta_sintoma sai por ON DELETE CASCADE)
SELECT c.id_consulta, c.status,
       (SELECT COUNT(*) FROM consulta_procedimento cp WHERE cp.id_consulta = c.id_consulta) AS procedimentos,
       (SELECT COUNT(*) FROM consulta_sintoma s       WHERE s.id_consulta  = c.id_consulta) AS sintomas
FROM consulta c WHERE c.id_consulta = 16;
START TRANSACTION;
DELETE FROM consulta_procedimento WHERE id_consulta = 16;               -- 1) filha (RESTRICT)
DELETE FROM consulta WHERE id_consulta = 16 AND status = 'CANCELADA';   -- 2) pai (cascade nos sintomas)
SELECT COUNT(*) AS consulta_16_restante FROM consulta WHERE id_consulta = 16;           -- esperado: 0
SELECT COUNT(*) AS sintomas_orfaos      FROM consulta_sintoma WHERE id_consulta = 16;   -- esperado: 0
COMMIT;

-- D4: exclui tutor SEM animais (telefones saem por ON DELETE CASCADE)
SELECT t.id_tutor, t.nome,
       (SELECT COUNT(*) FROM animal a WHERE a.id_tutor = t.id_tutor) AS animais
FROM tutor t WHERE t.id_tutor = 8;
START TRANSACTION;
DELETE FROM tutor
 WHERE id_tutor = 8
   AND NOT EXISTS (SELECT 1 FROM animal a WHERE a.id_tutor = 8);
SELECT COUNT(*) AS tutor_8_restante    FROM tutor WHERE id_tutor = 8;            -- esperado: 0
SELECT COUNT(*) AS telefones_do_tutor_8 FROM telefone_tutor WHERE id_tutor = 8;  -- esperado: 0
COMMIT;

-- D5: remove medicamento descontinuado, sem estoque e nunca prescrito
START TRANSACTION;
DELETE FROM medicamento
 WHERE id_medicamento = 9
   AND estoque_atual = 0
   AND NOT EXISTS (SELECT 1 FROM prescricao p WHERE p.id_medicamento = 9);
SELECT COUNT(*) AS medicamento_9_restante FROM medicamento WHERE id_medicamento = 9;   -- esperado: 0
COMMIT;

-- D6 (ROLLBACK): exclusão exploratória desfeita. Remove as prescrições da consulta 5, confere e desfaz.
START TRANSACTION;
DELETE FROM prescricao WHERE id_consulta = 5;
SELECT COUNT(*) AS prescricoes_consulta_5 FROM prescricao WHERE id_consulta = 5;   -- dentro da transação: 0
ROLLBACK;
SELECT COUNT(*) AS prescricoes_consulta_5 FROM prescricao WHERE id_consulta = 5;   -- após o ROLLBACK: 1

-- ---------------------------------------------------------------------
-- TESTES NEGATIVOS (NÃO executar em lote: cada um interrompe o script com erro esperado)
-- Demonstram a proteção da integridade referencial e das restrições CHECK.
-- ---------------------------------------------------------------------
-- DELETE FROM tutor WHERE id_tutor = 1;
--   => ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails
--      (o tutor 1 possui animais; é preciso tratar a dependência antes)
-- UPDATE medicamento SET estoque_atual = -1 WHERE id_medicamento = 1;
--   => ERROR 3819: Check constraint 'ck_med_estoque' is violated.
-- INSERT INTO tutor (nome, cpf, cep, numero) VALUES ('Teste', '39053344705', '01310100', '1');
--   => ERROR 1062: Duplicate entry '39053344705' for key 'tutor.uq_tutor_cpf'
