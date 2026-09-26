#!/usr/bin/env bash
# Сравнение бесплатных моделей Groq на живой сцене «штольня» (3.9): N прогонов на модель.
# Модели идут параллельно — у каждой свой лимит 8000 токенов в минуту.
# Запуск: bash scripts/compare_models.sh N провайдер:модель...  → build/compare/<модель>.log и таблица.
# Пример: bash scripts/compare_models.sh 10 mistral:mistral-large-latest zai:glm-4.7-flash
# Модели — из supabase/functions/assistant/providers.ts.
set -u
N=${1:-10}; shift
MODELS=("$@")
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
for m in "${MODELS[@]}"; do run_model "$m" & done
wait
printf "%-22s %-8s %-10s %-9s\n" "модель" "прошло" "сек/прогон" "спросил"
for m in "${MODELS[@]}"; do
  f="build/compare/$(tr ':/' '__' <<<"$m").log"
  awk -F'|' -v m="$m" '{ok+=$2; t+=$3; q+=($4>0)} END {printf "%-22s %d/%d     %-10d %d/%d\n", m, ok, NR, t/NR, q, NR}' "$f"
done
