#!/usr/bin/env bash
# ЕДИНСТВЕННАЯ КОМАНДА ПРАВДЫ.
#
# ГЛАВНОЕ СВОЙСТВО: если проверять оказалось НЕЧЕМ — это КРАСНО, а не зелёно.
# Прибор, не проведший ни одного измерения, обязан кричать, а не молчать.
cd "$(dirname "$0")/.." || exit 1
RAN=0; NAMES=""

run() {  # run "человеческое имя" "команда"
  echo "--- $1 ---"
  if eval "$2"; then RAN=$((RAN+1)); NAMES="$NAMES $1"
  else echo ""; echo "КРАСНО: упало на «$1». Зелёный прогон НЕ зафиксирован."; exit 1; fi
}

# ---------- Python ----------
if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -d app ]; then
  PY="python"; command -v python >/dev/null 2>&1 || PY="python3"
  [ -f scripts/suite.py ] && run "сценарии (suite)" "$PY scripts/suite.py"
  if [ -d tests ] && ls tests/*.py >/dev/null 2>&1 && command -v pytest >/dev/null 2>&1; then
    run "pytest" "pytest -q"
  fi
  run "синтаксис" "$PY -m compileall -q app scripts 2>/dev/null || $PY -m compileall -q ."
  command -v ruff >/dev/null 2>&1 && run "ruff" "ruff check ."
fi

# ---------- Node ----------
if [ -f package.json ]; then
  if   [ -f pnpm-lock.yaml ]; then PM="pnpm run"
  elif [ -f yarn.lock ];      then PM="yarn run"
  else                             PM="npm run"; fi
  has() { node -e "const s=(require('./package.json').scripts)||{};process.exit(s['$1']?0:1)" 2>/dev/null; }
  if has check; then run "check" "$PM check"
  else
    has typecheck && run "typecheck" "$PM typecheck"
    has lint      && run "lint"      "$PM lint"
    has test:unit && run "юнит-тесты" "$PM test:unit"
    has test      && run "тесты"      "$PM test"
    has build     && run "сборка"     "$PM build"
    has test:e2e  && run "e2e"        "$PM test:e2e"
  fi
fi

# ---------- Flutter ----------
if [ -f pubspec.yaml ]; then
  # Тестовые авторы для проверки изоляции миров в настоящей базе.
  [ -f .env.test ] && { set -a; . ./.env.test; set +a; }
  run "анализатор Dart" "flutter analyze --no-pub"
  run "тесты (экраны + изоляция миров в базе)" "flutter test --no-pub"
fi

# ---------- серверная функция ассистента (TypeScript) ----------
if [ -d supabase/functions ]; then
  run "функция ассистента (подменённая модель)" "bash scripts/fn-test.sh"
fi

# ---------- честный отказ ----------
if [ "$RAN" -eq 0 ]; then
  echo ""
  echo "КРАСНО: НЕ НАЙДЕНО НИ ОДНОЙ ПРОВЕРКИ."
  echo "Это не «всё хорошо» — это значит, что прибора нет."
  echo "Допиши сюда команду, которая падает, когда продукт сломан,"
  echo "и обязательно убедись, что она умеет падать: сломай что-нибудь нарочно."
  exit 1
fi

mkdir -p .claude
{ date -Iseconds; git rev-parse --short HEAD 2>/dev/null || echo '-'; } > .claude/last-green
echo ""
echo "ЗЕЛЁНО. Проведено проверок: $RAN —$NAMES"
echo "Зафиксировано в .claude/last-green."
