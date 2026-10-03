#!/usr/bin/env bash
# Запись показа: настоящее приложение под Windows проходит сцену «штольня» (integration_test),
# ffmpeg пишет только окно приложения «rpg_builder» → build/demo/demo.mp4.
# Запуск: bash scripts/record_demo.sh
set -u
mkdir -p build/demo
set -a; . ./.env.test; set +a
flutter test integration_test/demo_video_test.dart -d windows --no-pub   --dart-define-from-file=.env \
  --dart-define=RPGB_TEST_EMAIL_T="$RPGB_TEST_EMAIL_T" \
  --dart-define=RPGB_TEST_PASSWORD="$RPGB_TEST_PASSWORD" > build/demo/test.log 2>&1 &
test_pid=$!
# Ждём окно приложения (сборка под Windows — до пары минут).
for _ in $(seq 1 300); do
  powershell -NoProfile -Command "if (Get-Process | Where-Object { \$_.MainWindowTitle -eq 'rpg_builder' }) { exit 0 } else { exit 1 }" && break
  sleep 1
done
ffmpeg -y -loglevel error -f gdigrab -framerate 15 -i title=rpg_builder \
  -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -pix_fmt yuv420p -movflags frag_keyframe+empty_moov build/demo/demo.mp4 &
ff_pid=$!
wait $test_pid; code=$?
kill -INT $ff_pid 2>/dev/null; wait $ff_pid 2>/dev/null
tail -3 build/demo/test.log
exit $code
