/* =====================================================================
   VetCare - Sistema de Gestão para Clínica Veterinária
   Arquivo : 03_dql_queries.sql  (DQL - consultas analíticas e views)
   SGBD    : MySQL 8.0
   Autor   : Carlos Gabriel Novo
   Pré-req.: 01_ddl_schema.sql e 02_dml_seed.sql executados.
   Conteúdo: 3 views de relatório + 13 consultas (JOIN, GROUP BY, HAVING,
             agregações, subconsultas). Somente leitura (SELECT / VIEW).
   Observação: os valores esperados nos comentários consideram o seed
               original, ANTES de executar 04_dml_updates_deletes.sql.
   ===================================================================== */

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
