/* =====================================================================
   VetCare - Sistema de Gestão para Clínica Veterinária
   Arquivo : 05_procedures_and_explain.sql (Stored Procedure + EXPLAIN)
   SGBD    : MySQL 8.0.16+
   Autor   : Carlos Gabriel Novo
   Pré-req.: 01_ddl_schema.sql e 02_dml_seed.sql executados.
   Conteúdo:
     - Parte A: Stored procedure transacional para registro de prescrição
                com baixa atômica de estoque e bloqueio pessimista
                (SELECT ... FOR UPDATE), evitando race conditions.
     - Parte B: Planos de execução (EXPLAIN) demonstrando o uso efetivo
                dos índices definidos em 01_ddl_schema.sql.
   ===================================================================== */

SET NAMES utf8mb4;
USE vetcare;

-- =====================================================================
-- PARTE A - STORED PROCEDURE TRANSACIONAL (PRESCRIÇÃO + ESTOQUE)
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_registrar_prescricao_e_baixar_estoque;

DELIMITER //

CREATE PROCEDURE sp_registrar_prescricao_e_baixar_estoque(
  IN p_id_consulta    INT,
  IN p_id_medicamento INT,
  IN p_posologia      VARCHAR(150),
  IN p_duracao_dias   INT,
  IN p_quantidade     INT
)
BEGIN
  DECLARE v_estoque_atual   INT;
  DECLARE v_status_consulta VARCHAR(20);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Quantidade prescrita deve ser maior que zero.';
  END IF;

  IF p_duracao_dias IS NULL OR p_duracao_dias <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Duração do tratamento deve ser maior que zero.';
  END IF;

  START TRANSACTION;

  -- Verifica existência e status da consulta sob lock de linha
  SELECT status
    INTO v_status_consulta
    FROM consulta
   WHERE id_consulta = p_id_consulta
     FOR UPDATE;

  IF v_status_consulta IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Consulta informada não existe.';
  END IF;

  IF v_status_consulta = 'CANCELADA' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Não é permitido registrar prescrição em consulta CANCELADA.';
  END IF;

  -- Lock pessimista no medicamento para impedir overselling em concorrência
  SELECT estoque_atual
    INTO v_estoque_atual
    FROM medicamento
   WHERE id_medicamento = p_id_medicamento
     FOR UPDATE;

  IF v_estoque_atual IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Medicamento informado não existe.';
  END IF;

  IF v_estoque_atual < p_quantidade THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Estoque insuficiente para registrar a prescrição.';
  END IF;

  INSERT INTO prescricao (id_consulta, id_medicamento, posologia, duracao_dias, quantidade)
  VALUES (p_id_consulta, p_id_medicamento, p_posologia, p_duracao_dias, p_quantidade);

  UPDATE medicamento
     SET estoque_atual = estoque_atual - p_quantidade
   WHERE id_medicamento = p_id_medicamento;

  COMMIT;
END //

DELIMITER ;

-- Exemplo de uso (comentado para não alterar o seed automaticamente):
-- CALL sp_registrar_prescricao_e_baixar_estoque(
--   15, 1, '1 comprimido a cada 12 horas', 7, 14
-- );

-- =====================================================================
-- PARTE B - ANÁLISE DE PLANOS DE EXECUÇÃO (EXPLAIN)
-- =====================================================================

-- 1) Índice composto ix_consulta_status_data (status, data_hora)
EXPLAIN
SELECT id_consulta, id_animal, id_veterinario, data_hora
  FROM consulta
 WHERE status = 'REALIZADA'
   AND data_hora >= '2026-01-01 00:00:00'
   AND data_hora <  '2027-01-01 00:00:00'
 ORDER BY data_hora DESC;

-- 2) Índice único uq_tutor_cpf (acesso tipo const)
EXPLAIN
SELECT id_tutor, nome, email, cep
  FROM tutor
 WHERE cpf = '39053344705';

-- 3) Índice ix_medicamento_estoque em consulta de estoque crítico
EXPLAIN
SELECT id_medicamento, nome_comercial, estoque_atual
  FROM medicamento
 WHERE estoque_atual < 50
 ORDER BY estoque_atual;

-- 4) Chave primária composta (id_consulta, id_procedimento) em consulta_procedimento
EXPLAIN
SELECT cp.id_procedimento, p.nome_procedimento, cp.quantidade, cp.valor_cobrado
  FROM consulta_procedimento cp
 INNER JOIN procedimento p ON p.id_procedimento = cp.id_procedimento
 WHERE cp.id_consulta = 5;
