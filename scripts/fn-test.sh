#!/usr/bin/env bash
# Тесты серверной функции ассистента (TypeScript, node --test на подменённой модели).
# Ноль прошедших тестов — КРАСНО: node сам отвечает «успех» на опечатку в пути или фильтре.
# Использование: bash scripts/fn-test.sh [фильтр имени теста]
cd "$(dirname "$0")/.." || exit 1
FILES=$(find supabase/functions -name '*_test.ts' 2>/dev/null)
[ -z "$FILES" ] && { echo "КРАСНО: не найдено ни одного *_test.ts"; exit 1; }
PASS=0; FAIL=0
for f in $FILES; do
  if [ -n "$1" ]; then out=$(node --test-name-pattern "$1" "$f" 2>&1); else out=$(node "$f" 2>&1); fi
  code=$?
  p=$(echo "$out" | sed -n 's/^# pass //p'); n=$(echo "$out" | sed -n 's/^# fail //p')
  PASS=$((PASS + ${p:-0})); FAIL=$((FAIL + ${n:-0}))
  if [ "$code" -ne 0 ] || [ "${n:-0}" -ne 0 ]; then
    echo "$out" | grep -E "^not ok|^# Subtest|error|Expected|actual|expected" | head -40
    FAIL=$((FAIL + 1))
  fi
done
echo "функция ассистента: прошло $PASS, упало $FAIL"
[ "$FAIL" -ne 0 ] && exit 1
[ "$PASS" -eq 0 ] && { echo "КРАСНО: не прошло ни одного теста"; exit 1; }
exit 0
