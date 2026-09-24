#!/usr/bin/env bash
# ПУТЬ ПРОЕКТА. Рисуется из FEATURES.md — устареть не может.
cd "$(dirname "$0")/.." || exit 1
[ -f FEATURES.md ] || { echo "Нет FEATURES.md"; exit 1; }
D=$(grep -c '^- \[x\]' FEATURES.md); R=$(grep -c '^- \[ \]' FEATURES.md)
T=$(sed -n '/Дальше по плану/,$p' FEATURES.md | grep -c '^- ')
ALL=$((D+R+T)); [ "$ALL" -eq 0 ] && ALL=1
PCT=$((D*100/ALL)); FILL=$((PCT*30/100))
BAR=""; i=0
while [ $i -lt 30 ]; do [ $i -lt $FILL ] && BAR="$BAR#" || BAR="$BAR."; i=$((i+1)); done
echo "ПУТЬ ПРОЕКТА"
echo "[$BAR] $PCT%   готово $D  ·  красных $R  ·  впереди $T"
echo
echo "─── СДЕЛАНО ───"
grep '^- \[x\]' FEATURES.md | sed 's/ | .*//; s/^- \[x\] /  + /'
R2=$(grep '^- \[ \]' FEATURES.md | sed 's/ | .*//; s/^- \[ \] /  ! /')
[ -n "$R2" ] && { echo; echo "─── КРАСНОЕ, ЧИНИТЬ ───"; echo "$R2"; }
echo
echo "─── ВПЕРЕДИ ───"
sed -n '/Дальше по плану/,$p' FEATURES.md | awk '
  /^### /{ sub(/^### /,""); printf "\n  %s\n", $0; next }
  /^- /{ sub(/^- /,""); printf "    . %s\n", $0 }'
