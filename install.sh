#!/usr/bin/env bash
# matrix-noir installer. Backs up anything it replaces; ./uninstall.sh puts it all back.
#
#   ./install.sh            interactive
#   ./install.sh --yes      accept defaults, install user-level extras (no sudo)
#   ./install.sh --deps     also install system packages with apt (asks for sudo)
#   ./install.sh --reconfigure   ask for name/logo/projects again
#   ./install.sh --no-extras     skip downloading starship / tte / Nerd Font / ble.sh / kitty
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/matrix-noir"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/matrix-noir"
MANIFEST="$DATA/manifest"
TS="$(date +%Y%m%d-%H%M%S)"

YES=0; DEPS=0; RECONF=0; EXTRAS=1
for a in "$@"; do
  case $a in
    -y|--yes) YES=1 ;;
    --deps) DEPS=1 ;;
    --reconfigure) RECONF=1 ;;
    --no-extras) EXTRAS=0 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $a"; exit 1 ;;
  esac
done

g=$'\e[38;2;63;185;80m'; n=$'\e[38;2;126;231;135m'; d=$'\e[38;2;95;110;99m'; a=$'\e[38;2;227;179;65m'
red=$'\e[38;2;255;123;114m'; r=$'\e[0m'
say()  { printf '%s▸%s %s\n' "$g" "$r" "$*"; }
note() { printf '  %s%s%s\n' "$d" "$*" "$r"; }
warn() { printf '%s!%s %s\n' "$a" "$r" "$*"; }
ask() {  # ask "question" default -> echoes answer
  local q=$1 def=${2-} ans
  if [ "$YES" = 1 ]; then echo "$def"; return; fi
  read -r -p "  $q ${def:+[$def] }" ans </dev/tty || true
  echo "${ans:-$def}"
}
yes_no() {  # yes_no "question" -> 0 for yes (default yes)
  [ "$YES" = 1 ] && return 0
  local ans; read -r -p "  $1 [Y/n] " ans </dev/tty || true
  [[ -z $ans || $ans == [yY]* ]]
}

printf '\n%s  m a t r i x - n o i r%s\n%s  dark coder terminal · binary logo · matrix animations%s\n\n' "$n" "$r" "$d" "$r"

mkdir -p "$DATA/bin" "$CONF_DIR" "$HOME/.local/bin"
touch "$MANIFEST"

# Copy src -> dest, backing up a different existing file first. Everything is recorded for uninstall.sh.
place() {
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
    if ! grep -qF "backup|$dest|" "$MANIFEST"; then   # keep only the first (pre-matrix-noir) backup
      cp -p "$dest" "$dest.bak-matrix-noir-$TS"
      echo "backup|$dest|$dest.bak-matrix-noir-$TS" >> "$MANIFEST"
      note "backed up $dest"
    fi
  fi
  cp "$src" "$dest"
  grep -qxF "file|$dest" "$MANIFEST" || echo "file|$dest" >> "$MANIFEST"
}

# ---------------------------------------------------------------- 1. dependencies
say "Checking tools"
APT_PKGS=()
need() {  # need <command> <apt package>
  if command -v "$1" >/dev/null 2>&1; then printf '  %s✓%s %s\n' "$g" "$r" "$1"
  else printf '  %s✗%s %s\n' "$red" "$r" "$1"; APT_PKGS+=("$2"); fi
}
need git git; need python3 python3; need jq jq; need fastfetch fastfetch
need eza eza; need batcat bat; need fzf fzf; need zoxide zoxide; need fdfind fd-find
need btop btop; need cbonsai cbonsai; need pipx pipx; need gawk gawk; need make make; need curl curl

if [ ${#APT_PKGS[@]} -gt 0 ]; then
  if command -v apt >/dev/null; then
    cmd="sudo apt install -y ${APT_PKGS[*]}"
    if [ "$DEPS" = 1 ]; then
      if [[ " ${APT_PKGS[*]} " == *" fastfetch "* ]] && ! apt-cache show fastfetch >/dev/null 2>&1; then
        warn "fastfetch isn't in your apt sources. On Ubuntu 24.04 add its PPA first:"
        note "sudo add-apt-repository ppa:zhangsongcui3371/fastfetch && sudo apt update"
      fi
      say "Installing system packages"; note "$cmd"
      sudo apt update && sudo apt install -y "${APT_PKGS[@]}" || warn "some packages failed; continuing"
    else
      warn "Missing system packages. Install them with:"
      note "$cmd"
      note "(or re-run ./install.sh --deps). Everything still installs; missing tools are skipped at runtime."
    fi
  else
    warn "Missing: ${APT_PKGS[*]}. Install them with your package manager."
  fi
fi

# ---------------------------------------------------------------- 2. user-level extras (no sudo)
if [ "$EXTRAS" = 1 ]; then
say "User-level extras"
if ! command -v starship >/dev/null && yes_no "Install starship prompt to ~/.local/bin?"; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null && note "starship installed"
fi
if ! command -v tte >/dev/null && command -v pipx >/dev/null && yes_no "Install terminaltexteffects (tte) with pipx?"; then
  pipx install terminaltexteffects >/dev/null && note "tte installed"
fi
if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font" && yes_no "Install JetBrainsMono Nerd Font to ~/.local/share/fonts?"; then
  fdir="$HOME/.local/share/fonts/JetBrainsMonoNerd"; mkdir -p "$fdir"
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C "$fdir" \
    && fc-cache -f >/dev/null && note "font installed"
fi
if [ ! -f "$HOME/.local/share/blesh/ble.sh" ] && command -v gawk >/dev/null && command -v make >/dev/null \
   && yes_no "Install ble.sh (autosuggestions + syntax highlighting) to ~/.local?"; then
  tmp=$(mktemp -d)
  git clone --quiet --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "$tmp/blesh" \
    && make -s -C "$tmp/blesh" install PREFIX="$HOME/.local" >/dev/null && note "ble.sh installed"
  rm -rf "$tmp"
fi
if ! command -v kitty >/dev/null && yes_no "Install kitty terminal to ~/.local/kitty.app?"; then
  curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n >/dev/null \
    && ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/" \
    && mkdir -p "$HOME/.local/share/applications" \
    && cp "$HOME/.local/kitty.app/share/applications/"kitty*.desktop "$HOME/.local/share/applications/" \
    && note "kitty installed"
fi
fi

# ---------------------------------------------------------------- 3. personal settings
if [ ! -f "$CONF_DIR/config" ] || [ "$RECONF" = 1 ]; then
  say "Personalize"
  user=${USER:-dev}
  logo=$(ask "Logo letters (2-4 chars, A-Z 0-9 . - _ ! /):" "$(printf '%s' "${user:0:3}" | tr '[:lower:]' '[:upper:]')")
  name=$(ask "Your name:" "$user")
  tagline=$(ask "Tagline (studio, team, or blank):" "")
  role=$(ask "Role line (or blank):" "developer")
  projects=$(ask "Project folders, space-separated (for commits today / boot / matrix):" "")
  {
    sed -n '1,2p' "$REPO/config.example"
    echo
    printf 'MN_LOGO="%s"\nMN_NAME="%s"\nMN_TAGLINE="%s"\nMN_ROLE="%s"\nMN_PROJECTS="%s"\n' \
      "$logo" "$name" "$tagline" "$role" "${projects//$HOME/\$HOME}"
    grep -E '^MN_GREETINGS=' "$REPO/config.example"
    echo
    sed -n '/^# Set to 0/,$p' "$REPO/config.example"
  } > "$CONF_DIR/config"
  note "saved $CONF_DIR/config"
else
  note "keeping existing $CONF_DIR/config (use --reconfigure to change it)"
fi

# ---------------------------------------------------------------- 4. files
say "Installing files"
for f in "$REPO"/bin/*; do install -m 755 "$f" "$DATA/bin/"; done
cp "$REPO/config/bash/pre.bash" "$REPO/config/bash/init.bash" "$DATA/"
note "commands  → $DATA/bin"

place "$REPO/config/starship/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
place "$REPO/config/fastfetch/config.jsonc" "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc"
place "$REPO/config/kitty/kitty.conf"       "${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
place "$REPO/config/blesh/blerc"            "$HOME/.blerc"
note "starship, fastfetch, kitty, ble.sh configs placed"

if command -v konsole >/dev/null; then
  kdir="${XDG_DATA_HOME:-$HOME/.local/share}/konsole"
  place "$REPO/config/konsole/MatrixNoir.colorscheme" "$kdir/MatrixNoir.colorscheme"
  place "$REPO/config/konsole/Matrix Noir.profile"    "$kdir/Matrix Noir.profile"
  krc="${XDG_CONFIG_HOME:-$HOME/.config}/konsolerc"
  if [ -f "$krc" ] && ! grep -qF "|$krc" "$MANIFEST"; then
    cp -p "$krc" "$krc.bak-matrix-noir-$TS"; echo "backup|$krc|$krc.bak-matrix-noir-$TS" >> "$MANIFEST"
  elif [ ! -f "$krc" ]; then
    echo "file|$krc" >> "$MANIFEST"   # we're creating it, so uninstall removes it
  fi
  python3 - "$krc" <<'PY'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); s = p.read_text() if p.exists() else ""
if "[Desktop Entry]" not in s:
    s = "[Desktop Entry]\nDefaultProfile=Matrix Noir.profile\n\n" + s
elif re.search(r"^DefaultProfile=.*$", s, re.M):
    s = re.sub(r"^DefaultProfile=.*$", "DefaultProfile=Matrix Noir.profile", s, flags=re.M)
else:
    s = s.replace("[Desktop Entry]", "[Desktop Entry]\nDefaultProfile=Matrix Noir.profile", 1)
p.write_text(s)
PY
  note "Konsole: \"Matrix Noir\" profile set as default"
fi

# ---------------------------------------------------------------- 5. .bashrc
say "Hooking into ~/.bashrc"
rc="$HOME/.bashrc"; touch "$rc"
if ! grep -qF "backup|$rc|" "$MANIFEST"; then
  cp -p "$rc" "$rc.bak-matrix-noir-$TS"; echo "backup|$rc|$rc.bak-matrix-noir-$TS" >> "$MANIFEST"
fi
python3 - "$rc" "$DATA" <<'PY'
import re, sys
from pathlib import Path
rc, data = Path(sys.argv[1]), sys.argv[2]
s = rc.read_text()
s = re.sub(r"# >>> matrix-noir.*?# <<< matrix-noir[^\n]*\n?", "", s, flags=re.S)   # idempotent
pre = f"# >>> matrix-noir (pre) >>>\n[ -f {data}/pre.bash ] && source {data}/pre.bash\n# <<< matrix-noir (pre) <<<\n"
post = f"\n# >>> matrix-noir >>>\n[ -f {data}/init.bash ] && source {data}/init.bash\n# <<< matrix-noir <<<\n"
rc.write_text(pre + s.rstrip("\n") + "\n" + post)
PY
note "added a line at the top and bottom of ~/.bashrc (between '>>> matrix-noir' markers)"

PATH="$DATA/bin:$PATH" devver --refresh >/dev/null 2>&1 || true

printf '\n%s✓ matrix-noir installed.%s Open a new terminal (or run: exec bash).\n' "$n" "$r"
note "Konsole users: close every Konsole window once so it loads the new profile."
note "Settings: $CONF_DIR/config   ·   Undo everything: $REPO/uninstall.sh"
echo
