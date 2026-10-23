#!/usr/bin/env bash
# Remove matrix-noir and restore every file it backed up.
#   ./uninstall.sh            keeps your ~/.config/matrix-noir/config
#   ./uninstall.sh --purge    removes that too
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/matrix-noir"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/matrix-noir"
MANIFEST="$DATA/manifest"
g=$'\e[38;2;63;185;80m'; d=$'\e[38;2;95;110;99m'; r=$'\e[0m'

[ -f "$MANIFEST" ] || { echo "matrix-noir doesn't look installed (no $MANIFEST)"; exit 1; }

# Installed files: remove, then restore the pre-install backup if there was one
while IFS='|' read -r kind path _; do
  [ "$kind" = file ] && [ -e "$path" ] && rm -f "$path"
done < "$MANIFEST"
while IFS='|' read -r kind path backup; do
  [ "$path" = "$HOME/.bashrc" ] && continue   # keep edits made since install; markers are stripped below
  if [ "$kind" = backup ] && [ -e "$backup" ]; then
    mv -f "$backup" "$path"
    printf '  %srestored %s%s\n' "$d" "$path" "$r"
  fi
done < "$MANIFEST"

# ~/.bashrc: just remove the matrix-noir lines (its pre-install copy stays as ~/.bashrc.bak-matrix-noir-*)
rc="$HOME/.bashrc"
[ -f "$rc" ] && python3 - "$rc" <<'PY'
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(re.sub(r"\n?# >>> matrix-noir.*?# <<< matrix-noir[^\n]*\n?", "\n", p.read_text(), flags=re.S).lstrip("\n"))
PY

rm -rf "$DATA"
[ "${1-}" = "--purge" ] && rm -rf "$CONF_DIR"
printf '%s✓ matrix-noir removed.%s Open a new terminal. (starship, tte, ble.sh, kitty and the font were left installed.)\n' "$g" "$r"
