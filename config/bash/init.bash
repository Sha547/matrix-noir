# matrix-noir: sourced at the BOTTOM of ~/.bashrc. Every block checks its tool exists first.
[[ $- == *i* ]] || return

MN_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/matrix-noir"
case ":$PATH:" in *":$MN_HOME/bin:"*) ;; *) PATH="$MN_HOME/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/matrix-noir/config" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/matrix-noir/config"

# --- Modern CLI tools ---
command -v batcat >/dev/null && ! command -v bat >/dev/null && alias bat='batcat'

if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --git --group-directories-first --time-style=relative'
  alias la='eza -la --icons --git --group-directories-first --time-style=relative'
  alias l='eza -1 --icons'
  alias lt='eza --tree --level=2 --icons --git-ignore'
fi

if command -v bat >/dev/null || command -v batcat >/dev/null; then
  export BAT_THEME="ansi"   # follows the terminal's palette
  alias cat='bat --paging=never --style=plain'
  alias catn='bat --paging=never'
  export MANPAGER="sh -c 'col -bx | ${BASH_ALIASES[bat]:-bat} -l man -p'"
fi

if command -v fzf >/dev/null; then
  export FZF_DEFAULT_OPTS="--height 45% --layout=reverse --border=rounded --info=inline --prompt='❯ ' --pointer='▸' --marker='+' \
    --color=bg+:#141915,bg:-1,spinner:#7ee787,hl:#3fb950,fg:#c8d3ca,header:#56d4dd,info:#5f6e63 \
    --color=pointer:#7ee787,marker:#e3b341,fg+:#f0f6f1,prompt:#3fb950,hl+:#7ee787,border:#2a332c,gutter:-1"
  command -v fdfind >/dev/null && export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --exclude .git --exclude node_modules'
  command -v fd >/dev/null && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --exclude node_modules'
  if command -v bat >/dev/null || command -v batcat >/dev/null; then
    export FZF_CTRL_T_OPTS="--preview '${BASH_ALIASES[bat]:-bat} --color=always --style=numbers --line-range :200 {}'"
  fi
  command -v eza >/dev/null && export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
  # Ctrl+R history, Ctrl+T files, Alt+C dirs
  if [[ ${BLE_VERSION-} ]]; then
    ble-import -d integration/fzf-completion
    ble-import -d integration/fzf-key-bindings
  elif fzf --bash >/dev/null 2>&1; then eval "$(fzf --bash)"
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/bash-completion/completions/fzf ] && source /usr/share/bash-completion/completions/fzf
  fi
fi

command -v cbonsai >/dev/null && alias bonsai='cbonsai -li'
alias neofetch='devfetch --fx'

# --- Prompt ---
command -v starship >/dev/null && eval "$(starship init bash)"

# --- Startup screen: only new top-level interactive shells, not inside tmux / VS Code ---
if [[ $SHLVL -le 2 && -z ${TMUX-} && ${TERM_PROGRAM-} != vscode && ${MN_STARTUP:-1} != 0 ]]; then
  devfetch --fx
  unset STARSHIP_START_TIME   # don't count the banner as the first command's duration
fi

# --- Typo'd command -> glitch-animated error + "did you mean ...?" ---
command_not_found_handle() {
  if [[ -t 2 ]] && command -v cnf >/dev/null; then
    compgen -c | sort -u | cnf "$1"
  else
    printf 'bash: %s: command not found\n' "$1" >&2
  fi
  return 127
}

# --- cd into a different git repo -> animated one-line repo card (skips the starting dir and $HOME) ---
__mn_repocard_check() {
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z $top || $top == "$HOME" ]]; then __mn_repo_last=; __mn_repo_ready=1; return; fi
  [[ $top == "${__mn_repo_last-}" ]] && return
  __mn_repo_last=$top
  [[ ${__mn_repo_ready-} && ${MN_REPOCARD:-1} != 0 ]] && repocard
  __mn_repo_ready=1
}
if [[ ${BLE_VERSION-} ]]; then blehook PRECMD+=__mn_repocard_check
else PROMPT_COMMAND="__mn_repocard_check${PROMPT_COMMAND:+; $PROMPT_COMMAND}"; fi

# --- zoxide: `cd` learns your folders, `cdi` = fuzzy picker ---
command -v zoxide >/dev/null && eval "$(zoxide init bash --cmd cd)"

# --- ble.sh attaches last ---
[[ ${BLE_VERSION-} ]] && ble-attach
