#!/usr/bin/env bash
# ВХОД В СМЕНУ. Кладёт состояние проекта в контекст модели. Ничего не блокирует.
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(cygpath -u "$CLAUDE_PROJECT_DIR" 2>/dev/null)" 2>/dev/null || exit 0
. "$CLAUDE_PROJECT_DIR/.claude/hooks/_sid.sh" 2>/dev/null || . .claude/hooks/_sid.sh 2>/dev/null
INFO=$(read_hook_input); SID=$(printf '%s\n' "$INFO" | head -1); [ -z "$SID" ] && SID=shared
mkdir -p .claude/sessions 2>/dev/null

# МЁРТВЫЕ ОТМЕТКИ. Сессию могли убить жёстко — тогда SessionEnd не сработал
# и отметки остались навсегда. Считаем мёртвой ту, что не шевелилась 12 часов.
NOW=$(date +%s 2>/dev/null || echo 0)
for b in .claude/sessions/*.began; do
  [ -f "$b" ] || continue
  id=$(basename "$b" .began); newest=0
  for f in ".claude/sessions/$id."*; do
    [ -f "$f" ] || continue
    m=$(date -r "$f" +%s 2>/dev/null || echo 0)
    [ "$m" -gt "$newest" ] && newest=$m
  done
  [ $((NOW - newest)) -gt 43200 ] && rm -f ".claude/sessions/$id."* 2>/dev/null
done
date +%s > ".claude/sessions/$SID.began" 2>/dev/null
rm -f ".claude/sessions/$SID.touched" ".claude/sessions/$SID.blocks" 2>/dev/null

# ЦЕЛЬ — первой. Строитель не должен придумывать свои векторы.
if [ -f VISION.md ]; then
  echo "=== ЦЕЛЬ ПРОДУКТА (VISION.md) ==="
  awk '/^## .*[Гг]лавная задача/{f=1;next} /^## /{f=0} f' VISION.md | sed '/^[[:space:]]*$/d' | head -5
  echo; echo "=== ЧЕГО ПРОДУКТ НЕ ДЕЛАЕТ ==="
  awk '/^## .*НЕ делает/{f=1;next} /^## /{f=0} f' VISION.md | sed '/^[[:space:]]*$/d' | head -15
  echo; echo "Полный замысел — VISION.md. Прочитай до первой правки."
  echo
fi
# ПЕРВОЕ ДЕЙСТВИЕ. Скилл не подгружается сам, если в промпте нет слова «протокол».
echo "=== ПЕРВОЕ ДЕЙСТВИЕ ЭТОЙ СЕССИИ ==="
echo "Это проект с протоколом смены. До любой другой работы вызови скилл protocol"
echo "(инструмент Skill, skill: \"protocol\"). Владелец не должен об этом напоминать."
echo

echo "=== ТЕКУЩЕЕ СОСТОЯНИЕ ПРОЕКТА (STATE.md) ==="
if [ -f STATE.md ]; then sed -n '1,60p' STATE.md; else echo "STATE.md ещё не создан."; fi
echo; echo "=== ПОСЛЕДНЯЯ УСПЕШНАЯ ПРОВЕРКА ==="
if [ -f .claude/last-green ]; then cat .claude/last-green; else echo "НЕТ. Ни одной успешной проверки."; fi
echo; echo "=== ПОСЛЕДНИЕ КОММИТЫ ==="; git log --oneline -5 2>/dev/null || echo "(git недоступен)"
echo; echo "=== НЕЗАКОММИЧЕНО ==="; git status --porcelain 2>/dev/null | head -20
echo; echo "=== ПРАВИЛА ЭТОЙ СМЕНЫ ==="
echo "1. Срезы — по одному до зелёного. Несколько подряд можно, если понятия соседние."
echo "2. Работы нет в FEATURES.md или она против VISION.md — не делать, спросить владельца."
echo "3. Прежде чем сказать «готово» — bash scripts/check.sh"
echo "4. В STATE.md писать не «починили X», а КОМАНДУ, которая падает, если X сломан."
echo "5. Закрыл срез: STATE.md → ревью агентом slice-reviewer → свой коммит."
exit 0
