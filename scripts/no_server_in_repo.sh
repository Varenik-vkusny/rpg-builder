#!/usr/bin/env bash
# Репозиторий публичный: адрес сервера Supabase и ключ живут только в .env (не в git).
# Красно, если в отслеживаемых файлах есть адрес вида <проект>.supabase.co, ключ sb_publishable_…
# или имя проекта из .env. Нет .env или адрес в нём не читается — тоже красно: искать было бы нечем.
cd "$(dirname "$0")/.." || exit 1
[ -f .env ] || { echo "нет .env — см. README.md" >&2; exit 1; }
REF=$(sed -n 's#^SUPABASE_URL=https://\([a-z0-9]*\)\.supabase\.co.*#\1#p' .env)
[ -n "$REF" ] || { echo "не прочитал адрес сервера из .env" >&2; exit 1; }
git ls-files --error-unmatch .env >/dev/null 2>&1 && { echo ".env отслеживается git"; exit 1; }
# Ищем и в отслеживаемых, и в новых файлах (кроме тех, что в .gitignore). Код git grep: 0 — нашёл, 1 — чисто,
# иное — поиск не состоялся (не git-папка, ошибка): это красно, а не «чисто».
FOUND=$(git grep --untracked -nIE "[a-z0-9]{20}\.supabase\.co|sb_publishable_[A-Za-z0-9_-]{20,}|$REF" -- .); CODE=$?
[ "$CODE" -le 1 ] || { echo "поиск по репозиторию не состоялся (git grep: $CODE)" >&2; exit 1; }
if [ "$CODE" -eq 0 ]; then
  echo "$FOUND" | cut -c1-120; echo "адрес сервера или ключ попали в репозиторий"; exit 1
fi
echo "адреса сервера и ключа в репозитории нет"
