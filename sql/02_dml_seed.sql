/* =====================================================================
   VetCare - Sistema de Gestão para Clínica Veterinária
   Arquivo : 02_dml_seed.sql  (DML - povoamento / INSERT)
   SGBD    : MySQL 8.0
   Autor   : Carlos Gabriel Novo
   Pré-req.: 01_ddl_schema.sql já executado.
   Ordem   : tabelas independentes -> dependentes (pai -> filha).
   IMPORTANTE: todos os dados são FICTÍCIOS (nomes, CPFs, telefones,
   e-mails e endereços de exemplo); nenhuma informação real de pessoas.
   Os comentários "-- N" indicam o id gerado por AUTO_INCREMENT em um
   banco recém-criado (os INSERTs seguintes dependem dessa numeração).
   ===================================================================== */

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
