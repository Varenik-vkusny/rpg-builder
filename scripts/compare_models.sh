#!/usr/bin/env bash
# Сравнение бесплатных моделей Groq на живой сцене «штольня» (3.9): N прогонов на модель.
# Модели идут по очереди: параллельные flutter test в одной папке дерутся за build/test_cache
# (Windows, 26.09 — прогон висел 16 минут). Лимит Groq — 200 000 токенов в сутки на модель ≈ 10 прогонов.
# Запуск: bash scripts/compare_models.sh N провайдер:модель...  → build/compare/<модель>.log и таблица.
# Пример: bash scripts/compare_models.sh 10 mistral:mistral-large-latest zai:glm-4.7-flash
# Модели — из supabase/functions/assistant/providers.ts.
# Порог: --min K (сколько прогонов из N должно пройти; по умолчанию 8 из 10, то есть 80 % от N).
# Код возврата: 0 — все модели не ниже порога, 1 — хоть одна ниже, 2 — ошибка в аргументах.
# COMPARE_REPORT_ONLY=1 — не гонять модели, только посчитать по уже лежащим build/compare/<модель>.log.
set -u
MIN=""
if [ "${1:-}" = "--min" ]; then MIN=${2:-}; shift 2 || true; fi
N=${1:-}; shift || true
MODELS=("$@")
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "Ошибка: первое число — сколько прогонов (N), получено «$N»"; exit 2; }
[ ${#MODELS[@]} -gt 0 ] || { echo "Ошибка: не названо ни одной модели (провайдер:модель)"; exit 2; }
[ -z "$MIN" ] && MIN=$(( (N * 8 + 9) / 10 ))
[[ "$MIN" =~ ^[0-9]+$ ]] && [ "$MIN" -le "$N" ] || { echo "Ошибка: порог --min «$MIN» не число от 0 до $N"; exit 2; }
for m in "${MODELS[@]}"; do [[ "$m" == *:* ]] || { echo "Ошибка: модель «$m» без провайдера (нужно провайдер:модель)"; exit 2; }; done
mkdir -p build/compare
run_model() {
  local m=$1 f="build/compare/$(tr ':/' '__' <<<"$1").log"
  : > "$f"
  for i in $(seq 1 "$N"); do
    local t0=$SECONDS out
    out=$(RPGB_MODEL="$m" bash -c 'set -a; . ./.env.test; flutter test --no-pub live/shtolnya_scene_live_test.dart' 2>&1)
    echo "$out" > "${f%.log}-$i.out"  # полный вывод прогона — разбирать провалы
    local ok=0; grep -q "All tests passed" <<<"$out" && ok=1
    local why; why=$(grep -E "Ассистент не ответил|reason:|Expected:" <<<"$out" | head -1 | cut -c1-400)
    local asked; asked=$(grep -c "^ВОПРОС" <<<"$out")
    echo "$i|$ok|$((SECONDS - t0))|$asked|$why" >> "$f"
  done
}
[ "${COMPARE_REPORT_ONLY:-0}" = 1 ] || for m in "${MODELS[@]}"; do run_model "$m"; done
printf "%-22s %-8s %-10s %-9s\n" "модель" "прошло" "сек/прогон" "спросил"
for m in "${MODELS[@]}"; do
  f="build/compare/$(tr ':/' '__' <<<"$m").log"
  [ -s "$f" ] || { echo "КРАСНО: $m — нет ни одного прогона ($f)"; FAIL=1; continue; }
  awk -F'|' -v m="$m" '{ok+=$2; t+=$3; q+=($4>0)} END {printf "%-22s %d/%d     %-10d %d/%d\n", m, ok, NR, t/NR, q, NR}' "$f"
  ok=$(awk -F'|' '{ok+=$2} END {print ok+0}' "$f")
  [ "$ok" -ge "$MIN" ] || { echo "КРАСНО: $m — прошло $ok, порог $MIN из $N"; FAIL=1; }
done
[ "${FAIL:-0}" = 0 ] && echo "ЗЕЛЁНО: все модели не ниже порога $MIN из $N"
exit "${FAIL:-0}"
