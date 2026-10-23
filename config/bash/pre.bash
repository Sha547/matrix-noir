# matrix-noir: sourced at the TOP of ~/.bashrc.
# ble.sh (autosuggestions + syntax highlighting) has to load before everything else and attach last.
[[ $- == *i* && -f ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach
