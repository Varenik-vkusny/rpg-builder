#!/usr/bin/env bash
# Сравнение бесплатных моделей Groq на живой сцене «штольня» (3.9): N прогонов на модель.
# Модели идут по очереди: параллельные flutter test в одной папке дерутся за build/test_cache
# (Windows, 26.09 — прогон висел 16 минут). Лимит Groq — 200 000 токенов в сутки на модель ≈ 10 прогонов.
# Запуск: bash scripts/compare_models.sh N провайдер:модель...  → build/compare/<модель>.log и таблица.
# Пример: bash scripts/compare_models.sh 10 mistral:mistral-large-latest zai:glm-4.7-flash
# Модели — из supabase/functions/assistant/providers.ts.
# --event (до N): мир с событием «Засада у лебёдки» (RPGB_WITH_EVENT=1), логи с суффиксом -event.
# Прогон проваленный, если в выводе нет маркера мира: «МИР: чистый» (без --event) или «МИР: с событием» (с ним).
# Порог: --min K (сколько прогонов из N должно пройти; по умолчанию 8 из 10, то есть 80 % от N).
# Код возврата: 0 — все модели не ниже порога, 1 — хоть одна ниже, 2 — ошибка в аргументах.
# COMPARE_REPORT_ONLY=1 — не гонять модели, только посчитать по уже лежащим build/compare/<модель>.log.
set -u
MIN=""; EVENT=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --min) MIN=${2:-}; shift 2 || { echo "Ошибка: --min без значения"; exit 2; } ;;
    --event) EVENT=1; shift ;;
    *) echo "Ошибка: неизвестный флаг «$1» (есть --min K и --event)"; exit 2 ;;
  esac
done
if [ "$EVENT" = 1 ]; then SUF="-event"; MARK="МИР: с событием"; else SUF=""; MARK="МИР: чистый"; fi
N=${1:-}; shift || true
MODELS=("$@")
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "Ошибка: первое число — сколько прогонов (N), получено «$N»"; exit 2; }
[ ${#MODELS[@]} -gt 0 ] || { echo "Ошибка: не названо ни одной модели (провайдер:модель)"; exit 2; }
[ -z "$MIN" ] && MIN=$(( (N * 8 + 9) / 10 ))
[[ "$MIN" =~ ^[0-9]+$ ]] && [ "$MIN" -le "$N" ] || { echo "Ошибка: порог --min «$MIN» не число от 0 до $N"; exit 2; }
for m in "${MODELS[@]}"; do [[ "$m" == *:* ]] || { echo "Ошибка: модель «$m» без провайдера (нужно провайдер:модель)"; exit 2; }; done
mkdir -p build/compare
logf() { echo "build/compare/$(tr ':/' '__' <<<"$1")$SUF.log"; }
# Вердикт прогона по его выводу: 1 — прошёл И мерил тот мир, что просили (маркер); иначе 0.
# Команда, молча мерящая не тот мир, — худший прибор.
judge() {
  grep -q "All tests passed" <<<"$1" && grep -qF "$MARK" <<<"$1" && echo 1 || echo 0
}
run_model() {
  local m=$1 f; f=$(logf "$1")
  : > "$f"
  for i in $(seq 1 "$N"); do
    local t0=$SECONDS out
    out=$(RPGB_MODEL="$m" RPGB_WITH_EVENT="$EVENT" bash -c 'set -a; . ./.env.test; flutter test --no-pub live/shtolnya_scene_live_test.dart' 2>&1)
    echo "$out" > "${f%.log}-$i.out"  # полный вывод прогона — разбирать провалы
    local ok; ok=$(judge "$out")
    local why; why=$(grep -E "Ассистент не ответил|reason:|Expected:" <<<"$out" | head -1 | cut -c1-400)
    grep -qF "$MARK" <<<"$out" || why="нет маркера «$MARK» — мерили не тот мир. $why"
    local asked; asked=$(grep -c "^ВОПРОС" <<<"$out")
    echo "$i|$ok|$((SECONDS - t0))|$asked|$why" >> "$f"
  done
}
# Только отчёт: прогоны не гоняем, но вердикт пересчитываем по лежащим рядом полным выводам (-N.out),
# чтобы маркер мира проверялся и здесь.
rescore() {
  local f=$1 tmp="$1.tmp" i ok t asked why out
  : > "$tmp"
  while IFS='|' read -r i ok t asked why; do
    out="${f%.log}-$i.out"
    if [ -f "$out" ]; then
      ok=$(judge "$(cat "$out")")
      grep -qF "$MARK" "$out" || why="нет маркера «$MARK» — мерили не тот мир. $why"
    fi
    echo "$i|$ok|$t|$asked|$why" >> "$tmp"
  done < "$f"
  mv "$tmp" "$f"
}
if [ "${COMPARE_REPORT_ONLY:-0}" = 1 ]; then
  for m in "${MODELS[@]}"; do [ -s "$(logf "$m")" ] && rescore "$(logf "$m")"; done
else
  for m in "${MODELS[@]}"; do run_model "$m"; done
fi
printf "%-22s %-8s %-10s %-9s\n" "модель" "прошло" "сек/прогон" "спросил"
for m in "${MODELS[@]}"; do
  f=$(logf "$m")
  [ -s "$f" ] || { echo "КРАСНО: $m — нет ни одного прогона ($f)"; FAIL=1; continue; }
  awk -F'|' -v m="$m" '{ok+=$2; t+=$3; q+=($4>0)} END {printf "%-22s %d/%d     %-10d %d/%d\n", m, ok, NR, t/NR, q, NR}' "$f"
  ok=$(awk -F'|' '{ok+=$2} END {print ok+0}' "$f")
  [ "$ok" -ge "$MIN" ] || { echo "КРАСНО: $m — прошло $ok, порог $MIN из $N"; FAIL=1; }
done
[ "${FAIL:-0}" = 0 ] && echo "ЗЕЛЁНО: все модели не ниже порога $MIN из $N"
exit "${FAIL:-0}"
