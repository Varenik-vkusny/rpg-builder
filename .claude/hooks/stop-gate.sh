#!/usr/bin/env bash
# ГЕЙТ «ГОТОВО». Держит только ту сессию, которая САМА меняла код.
# Сессии планирования и параллельные сессии друг другу не мешают.
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(cygpath -u "$CLAUDE_PROJECT_DIR" 2>/dev/null)" 2>/dev/null || exit 0
. "$CLAUDE_PROJECT_DIR/.claude/hooks/_sid.sh" 2>/dev/null || . .claude/hooks/_sid.sh 2>/dev/null
INFO=$(read_hook_input); SID=$(printf '%s\n' "$INFO" | head -1); [ -z "$SID" ] && SID=shared
D=".claude/sessions"

# Эта сессия кода не касалась — выпускаем молча.
[ -f "$D/$SID.touched" ] || exit 0

BLOCKS=$(cat "$D/$SID.blocks" 2>/dev/null || echo 0)
case "$BLOCKS" in ''|*[!0-9]*) BLOCKS=0 ;; esac
if [ "$BLOCKS" -ge 2 ]; then
  echo "Гейт блокировал дважды — выпускаю, чтобы не зациклиться." >&2
  echo "ВНИМАНИЕ: состояние НЕ подтверждено. Скажи об этом владельцу прямо." >&2
  exit 0
fi

FAIL=""
if [ ! -f .claude/last-green ]; then
  FAIL="ни одной успешной проверки не зафиксировано"
else
  # НОВЕЙШИЙ ИСХОДНИК, а не отметка. Отметка ставится ПОСЛЕ команды, поэтому
  # «правка и проверка одной командой» всегда давала бы отметку позже зелёного.
  # Отметка решает, применять ли гейт вообще; свежесть — время самих файлов.
  NEWEST=""
  for f in $(git ls-files '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.css' '*.scss' '*.py' '*.vue' '*.svelte' '*.prisma' '*.sql' 2>/dev/null); do
    [ -f "$f" ] && [ "$f" -nt .claude/last-green ] && { NEWEST="$f"; break; }
  done
  [ -n "$NEWEST" ] && FAIL="код менялся после последней успешной проверки ($NEWEST)"
fi
if [ -f "$D/$SID.began" ] && [ ! STATE.md -nt "$D/$SID.began" ]; then
  FAIL="${FAIL:+$FAIL; }STATE.md не обновлён в этой сессии"
fi

if [ -n "$FAIL" ]; then
  mkdir -p "$D" 2>/dev/null; echo $((BLOCKS + 1)) > "$D/$SID.blocks" 2>/dev/null
  echo "ГЕЙТ НЕ ПРОЙДЕН: $FAIL" >&2
  echo "" >&2
  echo "Сделай два шага, прежде чем заканчивать:" >&2
  echo "  1) bash scripts/check.sh" >&2
  echo "  2) обнови STATE.md — срез, что зелёное, что красное (командой)" >&2
  exit 2
fi
exit 0
