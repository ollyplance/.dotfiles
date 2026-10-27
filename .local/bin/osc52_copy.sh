#!/usr/bin/env bash
# ==============================================================================
# osc52_copy.sh — Universal clipboard bridge (remote host -> local terminal via OSC-52,
# plus native pbcopy on macOS).
# Works from normal panes, copy-mode (y), AND nested popups like `C-h j` (scratch)!
# ==============================================================================

data=$(cat)
if [ -z "$data" ]; then
  exit 0
fi

encoded=$(printf "%s" "$data" | base64 | tr -d '\r\n')

if [ -n "$TMUX" ]; then
  # 1. Load into tmux's own clipboard buffer (-w triggers tmux native OSC-52 too)
  printf "%s" "$data" | tmux load-buffer -w - 2>/dev/null

  # 2. Send raw OSC-52 to EVERY attached tmux client TTY (crucial when inside C-h j
  #    `scratch` popup, where #{client_tty} is the inner popup PTY, while the outer
  #    xterm-kitty SSH TTY is another client in `tmux list-clients`!)
  for ctty in $(tmux list-clients -F '#{client_tty}' 2>/dev/null | sort -u); do
    if [ -n "$ctty" ] && [ -c "$ctty" ]; then
      printf "\033]52;c;%s\007" "$encoded" > "$ctty" 2>/dev/null
    fi
  done

  # 3. Also send wrapped DCS passthrough to the active pane TTY as fallback
  tty_path=$(tmux display-message -p '#{pane_tty}' 2>/dev/null)
  if [ -n "$tty_path" ] && [ -c "$tty_path" ]; then
    printf "\033Ptmux;\033\033]52;c;%s\007\033\\" "$encoded" > "$tty_path" 2>/dev/null
  fi
else
  # Outside tmux: normal OSC52 to /dev/tty
  printf "\033]52;c;%s\007" "$encoded" > /dev/tty 2>/dev/null
fi

# 4. macOS: also write the native clipboard directly (works even when the terminal
#    has OSC-52 disabled). Linux keeps relying on OSC-52 (xclip/wl-copy can keep the
#    copy-pipe open by forking a selection server).
if [ "$(uname -s)" = "Darwin" ] && command -v pbcopy >/dev/null 2>&1; then
  printf "%s" "$data" | pbcopy 2>/dev/null
fi

exit 0
