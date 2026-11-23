/* =====================================================================
   VetCare - Sistema de Gestão para Clínica Veterinária
   Arquivo : 04_dml_updates_deletes.sql  (DML - UPDATE e DELETE seguros)
   SGBD    : MySQL 8.0
   Autor   : Carlos Gabriel Novo
   Pré-req.: 01_ddl_schema.sql e 02_dml_seed.sql executados (banco recém-povoado).
   Padrão  : SELECT antes -> START TRANSACTION -> UPDATE/DELETE -> SELECT depois -> COMMIT
             (se o resultado não for o esperado, execute ROLLBACK em vez de COMMIT).
   Segurança:
     * todo UPDATE/DELETE tem WHERE por coluna de chave (compatível com "Safe Updates");
     * DELETE sempre na ordem FILHA -> PAI, respeitando ON DELETE RESTRICT / CASCADE;
     * proteção contra estoque negativo e exclusões indevidas dentro da própria condição.
   Atenção : o script altera dados. Para repetir, rode novamente 01 e 02.
   ===================================================================== */

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
