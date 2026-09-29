#!/usr/bin/env bash
# Автор А (RPGB_TEST_EMAIL_A) — для показа руками. Тесты, живые прогоны и видео под ним не входят и миров ему не добавляют.
#   bash scripts/author_a_worlds.sh start  — входит один раз, запоминает число миров и время входа
#   bash scripts/author_a_worlds.sh check  — тем же входом: миров не больше, и после start под А никто не входил
# Не смог войти или сосчитать — код 1: пустота не должна сойти за «всё хорошо».
cd "$(dirname "$0")/.." || exit 1
[ -f .env.test ] && { set -a; . ./.env.test; set +a; }
: "${RPGB_TEST_EMAIL_A:?нет RPGB_TEST_EMAIL_A}" "${RPGB_TEST_PASSWORD:?нет RPGB_TEST_PASSWORD}"
URL=$(sed -n "s/.*defaultValue: '\(https:[^']*\)'.*/\1/p" lib/config.dart)
KEY=$(sed -n "s/.*defaultValue: '\(sb_publishable_[^']*\)'.*/\1/p" lib/config.dart)
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "не нашёл адрес или ключ в lib/config.dart" >&2; exit 1; }
PY="python"; command -v python >/dev/null 2>&1 || PY="python3"
STATE=build/author_a.state  # build/ не попадает в git
json() { "$PY" -c "import json,sys; print(json.load(sys.stdin)$1)" 2>/dev/null; }

worlds() {  # RLS отдаёт только миры вошедшего автора
  curl -sf "$URL/rest/v1/projects?select=id" -H "apikey: $KEY" -H "Authorization: Bearer $1" \
    | "$PY" -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null
}
signed_in_at() {
  curl -sf "$URL/auth/v1/user" -H "apikey: $KEY" -H "Authorization: Bearer $1" | json '["last_sign_in_at"]'
}

case "$1" in
  start)
    BODY=$("$PY" -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2]}))' \
      "$RPGB_TEST_EMAIL_A" "$RPGB_TEST_PASSWORD")
    TOKEN=$(curl -sf "$URL/auth/v1/token?grant_type=password" -H "apikey: $KEY" \
      -H "Content-Type: application/json" -d "$BODY" | json '["access_token"]')
    [ -n "$TOKEN" ] || { echo "автор А не вошёл" >&2; exit 1; }
    N=$(worlds "$TOKEN"); AT=$(signed_in_at "$TOKEN")
    [ -n "$N" ] && [ -n "$AT" ] || { echo "не сосчитал миры автора А" >&2; exit 1; }
    mkdir -p build; printf '%s\n%s\n%s\n' "$TOKEN" "$N" "$AT" > "$STATE"
    echo "у автора А миров: $N"
    ;;
  check)
    [ -f "$STATE" ] || { echo "сначала start" >&2; exit 1; }
    { read -r TOKEN; read -r N0; read -r AT0; } < "$STATE"; rm -f "$STATE"
    N=$(worlds "$TOKEN"); AT=$(signed_in_at "$TOKEN")
    [ -n "$N" ] && [ -n "$AT" ] || { echo "не сосчитал миры автора А" >&2; exit 1; }
    echo "у автора А миров: было $N0, стало $N; последний вход: был $AT0, стал $AT"
    [ "$AT" = "$AT0" ] || { echo "под автором А входили во время тестов"; exit 1; }
    [ "$N" -le "$N0" ] || { echo "у автора А прибавились миры"; exit 1; }
    ;;
  *) echo "использование: author_a_worlds.sh start|check" >&2; exit 1 ;;
esac
