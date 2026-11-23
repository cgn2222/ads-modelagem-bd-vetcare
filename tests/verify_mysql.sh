#!/usr/bin/env bash
set -euo pipefail

# VetCare - Suite de verificação automatizada em MySQL 8.0+
# Executa DDL, seed, views/consultas, stored procedure, testes negativos de
# integridade (FK, CHECK, UNIQUE), DML transacional e o script consolidado.

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-vetcare_dev}"

export MYSQL_PWD="$MYSQL_PASSWORD"
MYSQL_CMD=(mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" --default-character-set=utf8mb4)

query_val() {
  "${MYSQL_CMD[@]}" -N -B -e "$1" vetcare
}

assert_eq() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "[FAIL] ${label}: esperado '${expected}', obtido '${actual}'" >&2
    exit 1
  fi
  echo "[OK]   ${label} = ${actual}"
}

assert_fails() {
  local label="$1"
  local sql="$2"
  local expected_pattern="$3"
  local output
  if output=$("${MYSQL_CMD[@]}" vetcare -e "$sql" 2>&1); then
    echo "[FAIL] ${label}: comando deveria falhar, mas executou com sucesso" >&2
    exit 1
  fi
  if [[ -n "$expected_pattern" ]] && ! grep -qiE "$expected_pattern" <<<"$output"; then
    echo "[FAIL] ${label}: erro inesperado -> ${output}" >&2
    exit 1
  fi
  echo "[OK]   ${label} bloqueado como esperado"
}

echo "==> 1. Executando DDL (01_ddl_schema.sql)"
"${MYSQL_CMD[@]}" < sql/01_ddl_schema.sql

echo "==> 2. Executando Seed (02_dml_seed.sql)"
"${MYSQL_CMD[@]}" < sql/02_dml_seed.sql > /dev/null

assert_eq "Total de tabelas base" \
  "$(query_val "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'vetcare' AND TABLE_TYPE = 'BASE TABLE'")" \
  "16"

assert_eq "Total de chaves estrangeiras" \
  "$(query_val "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = 'vetcare' AND CONSTRAINT_TYPE = 'FOREIGN KEY'")" \
  "15"

assert_eq "Linhas em tutor" "$(query_val "SELECT COUNT(*) FROM tutor")" "8"
assert_eq "Linhas em animal" "$(query_val "SELECT COUNT(*) FROM animal")" "11"
assert_eq "Linhas em consulta" "$(query_val "SELECT COUNT(*) FROM consulta")" "19"
assert_eq "Linhas em consulta_procedimento" "$(query_val "SELECT COUNT(*) FROM consulta_procedimento")" "37"
assert_eq "Linhas em prescricao" "$(query_val "SELECT COUNT(*) FROM prescricao")" "13"

echo "==> 3. Executando Views e Consultas DQL (03_dql_queries.sql)"
"${MYSQL_CMD[@]}" < sql/03_dql_queries.sql > /dev/null

assert_eq "Total de views criadas" \
  "$(query_val "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'vetcare' AND TABLE_TYPE = 'VIEW'")" \
  "3"

assert_eq "Valor total da consulta 5 (vw_consulta_valor_total)" \
  "$(query_val "SELECT valor_total FROM vw_consulta_valor_total WHERE id_consulta = 5")" \
  "650.00"

echo "==> 4. Executando Stored Procedure e EXPLAIN (05_procedures_and_explain.sql)"
"${MYSQL_CMD[@]}" < sql/05_procedures_and_explain.sql > /dev/null

# Teste positivo da procedure (consulta 15 REALIZADA, medicamento 1 com estoque 400)
"${MYSQL_CMD[@]}" vetcare -e "CALL sp_registrar_prescricao_e_baixar_estoque(15, 1, '1 comprimido a cada 12h', 5, 10);"
assert_eq "Estoque apos procedure (medicamento 1)" \
  "$(query_val "SELECT estoque_atual FROM medicamento WHERE id_medicamento = 1")" \
  "390"
assert_eq "Prescricao criada pela procedure (consulta 15, med 1)" \
  "$(query_val "SELECT quantidade FROM prescricao WHERE id_consulta = 15 AND id_medicamento = 1")" \
  "10"

# Restaura estado do seed apos o teste positivo da procedure
"${MYSQL_CMD[@]}" vetcare -e "DELETE FROM prescricao WHERE id_consulta = 15 AND id_medicamento = 1; UPDATE medicamento SET estoque_atual = 400 WHERE id_medicamento = 1;"

# Testes negativos da procedure
assert_fails "Procedure rejeita estoque insuficiente" \
  "CALL sp_registrar_prescricao_e_baixar_estoque(15, 5, 'Dose unica', 1, 999);" \
  "Estoque insuficiente"

assert_eq "Estoque preservado apos rollback da procedure (med 5)" \
  "$(query_val "SELECT estoque_atual FROM medicamento WHERE id_medicamento = 5")" \
  "25"

assert_fails "Procedure rejeita consulta CANCELADA" \
  "CALL sp_registrar_prescricao_e_baixar_estoque(16, 1, '1 comp 12/12h', 5, 10);" \
  "CANCELADA"

echo "==> 5. Testes negativos de integridade (FK, CHECK, UNIQUE)"
assert_fails "FK ON DELETE RESTRICT impede excluir tutor com animais" \
  "DELETE FROM tutor WHERE id_tutor = 1;" \
  "1451|foreign key constraint fails"

assert_fails "CHECK ck_med_estoque impede estoque negativo" \
  "UPDATE medicamento SET estoque_atual = -1 WHERE id_medicamento = 1;" \
  "3819|ck_med_estoque"

assert_fails "UNIQUE uq_tutor_cpf impede CPF duplicado" \
  "INSERT INTO tutor (nome, cpf, cep, numero) VALUES ('Teste', '39053344705', '01310100', '1');" \
  "1062|uq_tutor_cpf"

assert_fails "CHECK ck_tutor_cpf_formato impede CPF invalido" \
  "INSERT INTO tutor (nome, cpf, cep, numero) VALUES ('Teste2', '1234567890A', '01310100', '1');" \
  "3819|ck_tutor_cpf_formato"

echo "==> 6. Executando DML transacional (04_dml_updates_deletes.sql)"
"${MYSQL_CMD[@]}" < sql/04_dml_updates_deletes.sql > /dev/null

assert_eq "Estoque Apoquel (med 6) apos U3" \
  "$(query_val "SELECT estoque_atual FROM medicamento WHERE id_medicamento = 6")" \
  "186"

assert_eq "Consulta 17 atualizada para REALIZADA (U2)" \
  "$(query_val "SELECT status FROM consulta WHERE id_consulta = 17")" \
  "REALIZADA"

assert_eq "Consulta 16 removida (D3)" \
  "$(query_val "SELECT COUNT(*) FROM consulta WHERE id_consulta = 16")" \
  "0"

assert_eq "Sintomas da consulta 16 removidos em cascata (D3)" \
  "$(query_val "SELECT COUNT(*) FROM consulta_sintoma WHERE id_consulta = 16")" \
  "0"

assert_eq "Tutor 8 removido (D4)" \
  "$(query_val "SELECT COUNT(*) FROM tutor WHERE id_tutor = 8")" \
  "0"

assert_eq "Prescricao da consulta 5 preservada apos ROLLBACK (D6)" \
  "$(query_val "SELECT COUNT(*) FROM prescricao WHERE id_consulta = 5")" \
  "1"

echo "==> 7. Smoke test do script consolidado (vetcare_completo.sql)"
"${MYSQL_CMD[@]}" < sql/vetcare_completo.sql > /dev/null
assert_eq "Tabelas apos vetcare_completo.sql" \
  "$(query_val "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'vetcare' AND TABLE_TYPE = 'BASE TABLE'")" \
  "16"

echo ""
echo "Todos os testes de schema, seed, views, procedure, constraints e transacoes passaram em MySQL 8.0!"
