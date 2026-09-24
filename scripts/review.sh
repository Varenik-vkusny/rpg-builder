#!/usr/bin/env bash
# ГОТОВИТ МАТЕРИАЛ ДЛЯ РЕВЬЮ. Сам ничего не судит.
# Отдаёт ровно то, что нужно проверяющему: изменения, размеры, инварианты.
# Использование: bash scripts/review.sh [база, по умолчанию HEAD]
cd "$(dirname "$0")/.." || exit 1
BASE="${1:-HEAD}"

echo "===== РАЗМЕР ИЗМЕНЕНИЙ ====="
git diff --stat "$BASE" 2>/dev/null
git status --porcelain 2>/dev/null | grep '^??' | sed 's/^?? /новый файл: /'

echo
echo "===== РАЗМЕРЫ ЗАТРОНУТЫХ ФАЙЛОВ (порог 400 строк) ====="
{ git diff --name-only "$BASE" 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
  | sort -u | while read -r f; do
      [ -f "$f" ] || continue
      case "$f" in *.cs|*.sh|*.asmdef|*.csproj|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.py|*.vue|*.svelte|*.go|*.rs)
        n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
        if [ "${n:-0}" -gt 400 ]; then echo "  ПРЕВЫШЕН  $n  $f"; else echo "  ок        $n  $f"; fi ;;
      esac
    done

echo
echo "===== ИНВАРИАНТЫ ПРОЕКТА (из VISION.md) ====="
if [ -f VISION.md ]; then
  awk '/^## .*[Пп]равила, которые нельзя нарушать/{f=1;next} /^## /{f=0} f' VISION.md
else
  echo "(VISION.md нет)"
fi

echo
echo "===== НОВЫЕ СТРОКИ В FEATURES.md ====="
git diff "$BASE" -- FEATURES.md 2>/dev/null | grep '^+' | grep -v '^+++' | sed 's/^+/  /'

echo
echo "===== ИЗМЕНЕНИЯ ====="
git --no-pager diff "$BASE" 2>/dev/null
{ git ls-files --others --exclude-standard 2>/dev/null; } | while read -r f; do
  case "$f" in *.cs|*.sh|*.asmdef|*.csproj|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.py|*.vue|*.svelte|*.sql|*.prisma)
    echo "--- НОВЫЙ ФАЙЛ: $f ---"; cat "$f" ;;
  esac
done
