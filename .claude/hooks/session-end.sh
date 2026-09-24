#!/usr/bin/env bash
# ВЫХОД. Блокировать не умеет. Пишет строку в журнал замеров и убирает за собой.
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(cygpath -u "$CLAUDE_PROJECT_DIR" 2>/dev/null)" 2>/dev/null || exit 0
. "$CLAUDE_PROJECT_DIR/.claude/hooks/_sid.sh" 2>/dev/null || . .claude/hooks/_sid.sh 2>/dev/null
INFO=$(read_hook_input); SID=$(printf '%s\n' "$INFO" | head -1); [ -z "$SID" ] && SID=shared
D=".claude/sessions"; mkdir -p "$D" 2>/dev/null
GREEN="нет"; [ -f .claude/last-green ] && GREEN=$(head -1 .claude/last-green 2>/dev/null)
TOUCHED=нет; [ -f "$D/$SID.touched" ] && TOUCHED=да
BLOCKED=$(cat "$D/$SID.blocks" 2>/dev/null || echo 0)
printf '%s\tсессия=%s\tтрогала_код=%s\tHEAD=%s\tгрязных=%s\tпроверка=%s\tгейт=%s\n' \
  "$(date -Iseconds 2>/dev/null)" "$SID" "$TOUCHED" \
  "$(git rev-parse --short HEAD 2>/dev/null || echo '-')" \
  "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')" \
  "$GREEN" "$BLOCKED" >> .claude/sessions.log 2>/dev/null
rm -f "$D/$SID.began" "$D/$SID.touched" "$D/$SID.blocks" 2>/dev/null
exit 0
