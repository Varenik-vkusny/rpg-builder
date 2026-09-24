#!/usr/bin/env bash
# Помечает ИМЕННО ЭТУ сессию как тронувшую код.
# Ловит и правки инструментами, и правки через шелл — но НЕ чтение.
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(cygpath -u "$CLAUDE_PROJECT_DIR" 2>/dev/null)" 2>/dev/null || exit 0
. "$CLAUDE_PROJECT_DIR/.claude/hooks/_sid.sh" 2>/dev/null || . .claude/hooks/_sid.sh 2>/dev/null

INFO=$(read_hook_input)
SID=$(printf '%s\n' "$INFO" | sed -n '1p'); [ -z "$SID" ] && SID=shared
FP=$(printf '%s\n' "$INFO" | sed -n '2p')
CMD=$(printf '%s\n' "$INFO" | sed -n '3p')

SRC='\.(ts|tsx|js|jsx|mjs|cjs|css|scss|py|vue|svelte|prisma|sql|go|rs|json)'
MARK=0

# 1) Правка файлом — Edit / Write / NotebookEdit
case "$FP" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.css|*.scss|*.py|*.vue|*.svelte|*.prisma|*.sql|*.go|*.rs) MARK=1 ;;
esac

# 2) Правка через шелл — только пишущие команды, чтение игнорируем
# ТЕКСТ О КОДЕ — НЕ КОД.
# Команды, которые несут прозу о коде и сами файлов не правят:
# git commit с сообщением, git log/show/diff, эхо в терминал.
case "$CMD" in
  git\ commit*|git\ log*|git\ show*|git\ diff*|git\ status*|git\ tag*|git\ blame*)
    exit 0 ;;
esac

if [ "$MARK" -eq 0 ] && [ -n "$CMD" ]; then
  # Цель перенаправления — ОДИН токен. Иначе «>/dev/null && node x.mjs»
  # читается как запись в x.mjs.
  # Стрелки -> и => это не перенаправление: они живут внутри строк формата
  # (curl -w "... -> %{http_code}") и в стрелочных функциях. Выкидываем до проверки.
  #
  # Отдельно ловим запись ИЗ СКРИПТА: python в heredoc или node -e правят файл
  # не перенаправлением, а вызовом. Это самый частый способ правки, и без
  # этих трёх образцов гейт его не видел вовсе.
  CMD=$(printf '%s' "$CMD" | sed -e 's/->/ /g' -e 's/=>/ /g'         -e "s/-m[[:space:]]*'[^']*'/-m ..../g" -e 's/-m[[:space:]]*"[^"]*"/-m ..../g')
  if printf '%s' "$CMD" | grep -qiE "(>>?[[:space:]]*[^[:space:]|&;]*$SRC|sed[[:space:]]+-i[^|&;]*$SRC|tee[^|&;]*$SRC|patch[^|&;]*$SRC|(cp|mv|rm)[[:space:]]+[^|&;]*$SRC|npx[[:space:]]|pnpm[[:space:]]+(add|create|dlx)|npm[[:space:]]+(install|i)[[:space:]]|writeFileSync\([^)]*$SRC|open\([^)]*$SRC[^)]*[\"']w[\"'])"; then
    MARK=1
  fi
  # Путь к файлу часто лежит в ПЕРЕМЕННОЙ: `p='src/lib/x.ts'; open(p,'w')`.
  # Тогда расширение стоит не внутри скобок вызова, и образец выше слеп —
  # а это самый частый способ правки. Метим, если в команде есть И путь
  # к исходнику, И вызов записи. Правка документов сюда не попадает:
  # у FEATURES.md и STATE.md расширения из списка нет.
  if [ "$MARK" -eq 0 ] &&
     printf '%s' "$CMD" | grep -qiE "$SRC" &&
     printf '%s' "$CMD" | grep -qiE "(\.write\(|writeFileSync|open\([^)]*[\"']w[\"'])"; then
    MARK=1
  fi
fi

if [ "$MARK" -eq 1 ]; then
  mkdir -p .claude/sessions 2>/dev/null
  : > ".claude/sessions/$SID.touched" 2>/dev/null
fi
exit 0
