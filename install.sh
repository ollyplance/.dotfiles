#!/usr/bin/env bash
# ==============================================================================
#  PERSONAL DOTFILES BOOTSTRAPPER  (macOS + Linux, bash 3.2 compatible)
# ==============================================================================
#
#  ./install.sh                 full install: packages, shell plugins, symlinks,
#                               keyboard (Caps Lock -> Ctrl), private overlay
#  ./install.sh --adopt         like above, but FIRST copy any existing real
#                               config files on this machine INTO the repo
#                               (so `git diff` shows what this machine had),
#                               then symlink. Use on a machine whose configs
#                               aren't in the repo yet, then review + commit.
#  ./install.sh --scan          list config files/dirs on this machine that the
#                               repo does NOT manage yet (candidates to add)
#  ./install.sh --links-only    only (re)create symlinks (+ overlay links)
#  ./install.sh --no-packages   skip Homebrew / apt
#  ./install.sh --dry-run       print what would happen, change nothing
#
#  Existing real files are never deleted: they're moved to <file>.bak.<ts>.
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORP_DIR="${DOTFILES_CORP_DIR:-$HOME/.dotfiles-corp}"
OS="$(uname -s)"
TS="$(date +%Y%m%d%H%M%S)"
LOG="$HOME/.dotfiles-install.log"
START=$SECONDS

DO_PACKAGES=1
DO_BOOTSTRAP=1
DO_KEYBOARD=1
ADOPT=0
DRY=0
SCAN=0

for arg in "$@"; do
  case "$arg" in
    --adopt) ADOPT=1 ;;
    --scan) SCAN=1 ;;
    --links-only) DO_PACKAGES=0; DO_BOOTSTRAP=0; DO_KEYBOARD=0 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --no-keyboard) DO_KEYBOARD=0 ;;
    --dry-run|-n) DRY=1 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# ------------------------------------------------------------------------------
# Pretty output
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { printf "${YELLOW}==>${NC} %s ${BLUE}[%dm%02ds]${NC}\n" "$*" $(( (SECONDS-START)/60 )) $(( (SECONDS-START)%60 )); }

# with_heartbeat <label> <cmd...>: run a quiet, slow command with its output in
# $LOG, printing "still working" every 15s so it never looks hung.
with_heartbeat() {
  local label="$1"; shift
  if [[ $DRY -eq 1 ]]; then info "[dry-run]" "$*"; return 0; fi
  echo "----- $(date) $label: $*" >> "$LOG"
  "$@" >> "$LOG" 2>&1 &
  local pid=$! t=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; t=$((t+1))
    (( t % 15 == 0 )) && info "..." "$label still running (${t}s) - tail -f $LOG"
  done
  wait "$pid"
}
ok()   { printf "    ${GREEN}%s${NC} %s\n" "$1" "${2:-}"; }
info() { printf "    ${BLUE}%s${NC} %s\n" "$1" "${2:-}"; }
warn() { printf "    ${RED}!!${NC} %s\n" "$*"; }
run()  { if [[ $DRY -eq 1 ]]; then info "[dry-run]" "$*"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------------------
# What we manage:  "<path in repo>|<target relative to $HOME>|<os: all|Darwin|Linux>"
# Directories are linked as a whole. Add new entries here.
# ------------------------------------------------------------------------------
MANAGED="
.zshrc|.zshrc|all
.p10k.zsh|.p10k.zsh|all
.config/zsh|.config/zsh|all
.tmux.conf|.tmux.conf|all
.gitconfig|.gitconfig|all
.config/nvim|.config/nvim|all
.config/kitty|.config/kitty|all
.config/jj/config.toml|.config/jj/config.toml|all
.taskrc|.taskrc|all
.latexmkrc|.latexmkrc|all
.aerospace.toml|.aerospace.toml|Darwin
"

os_matches() { [[ "$1" == "all" || "$1" == "$OS" ]]; }

# Every executable in .local/bin is linked individually into ~/.local/bin
bin_entries() {
  local f
  for f in "$DOTFILES_DIR/.local/bin/"*; do
    [[ -f "$f" ]] && echo ".local/bin/$(basename "$f")|.local/bin/$(basename "$f")|all"
  done
  return 0
}

all_entries() { echo "$MANAGED" | sed '/^[[:space:]]*$/d'; bin_entries; }

# ------------------------------------------------------------------------------
# safe_link <src> <dest>: symlink, backing up any real file that's in the way
# ------------------------------------------------------------------------------
safe_link() {
  local src="$1" dest="$2"
  [[ -e "$src" || -L "$src" ]] || return 0
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    return 0  # already correct
  fi
  run mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    run rm "$dest"
  elif [[ -e "$dest" ]]; then
    info "backup" "$dest -> $dest.bak.$TS"
    run mv "$dest" "$dest.bak.$TS"
  fi
  run ln -s "$src" "$dest"
  ok "linked" "${dest/#$HOME/~}"
}

# ------------------------------------------------------------------------------
# adopt <repo_path> <dest>: copy a real (non-symlink) file/dir from $HOME into
# the repo so the machine's version shows up in `git diff`.
# ------------------------------------------------------------------------------
adopt() {
  local repo_path="$DOTFILES_DIR/$1" dest="$2"
  [[ -e "$dest" && ! -L "$dest" ]] || return 0
  if [[ -d "$dest" ]]; then
    if diff -rq "$dest" "$repo_path" >/dev/null 2>&1; then return 0; fi
    info "adopt" "${dest/#$HOME/~}/ -> repo"
    run mkdir -p "$repo_path"
    if have rsync; then
      run rsync -a --exclude .git --exclude .DS_Store "$dest/" "$repo_path/"
    else
      run cp -R "$dest/." "$repo_path/"
    fi
  else
    if [[ -f "$repo_path" ]] && cmp -s "$dest" "$repo_path"; then return 0; fi
    info "adopt" "${dest/#$HOME/~} -> repo"
    run mkdir -p "$(dirname "$repo_path")"
    run cp -p "$dest" "$repo_path"
  fi
}

# ------------------------------------------------------------------------------
# --scan: show unmanaged configs that probably belong in the repo
# ------------------------------------------------------------------------------
scan() {
  step "Configs on this machine that the repo does not manage yet:"
  local managed_targets candidate name
  managed_targets="$(all_entries | cut -d'|' -f2)"
  for candidate in "$HOME"/.config/* "$HOME"/.[a-zA-Z]*; do
    [[ -e "$candidate" ]] || continue
    name="${candidate#$HOME/}"
    case "$name" in
      .cache|.local|.config|.Trash|.DS_Store|.CFUserTextEncoding|.ssh|.gnupg|.oh-my-zsh|.zsh|.zsh-vi-mode|.tmux|.npm|.nvm|.cargo|.rustup|.docker|.kube|.vscode*|.cups|.zsh_history|.zsh_sessions|.histfile|.bash_history|.lesshst|.viminfo|.python_history|.wget-hsts|.zcompdump*|*.bak.*|.dotfiles|.dotfiles-corp|.config/gcloud|.config/configstore|.config/google-chrome|.config/pulse|.config/dconf|.config/systemd|.config/goa-1.0|.config/gtk-*|.config/ibus|.config/evolution|.config/enchant|.config/nautilus|.config/procps|.config/chrome-remote-desktop|.config/gnome-*|.config/*.list|.config/user-dirs.*|.config/mimeapps.list) continue ;;
    esac
    if ! echo "$managed_targets" | grep -qx "$name" && ! echo "$managed_targets" | grep -q "^$name/"; then
      [[ -L "$candidate" ]] && continue
      echo "    $name"
    fi
  done
  echo
  echo "    To add one: copy it into $DOTFILES_DIR (same relative path) and add a"
  echo "    line to MANAGED in install.sh, e.g.  .config/karabiner|.config/karabiner|Darwin"
}

if [[ $SCAN -eq 1 ]]; then scan; exit 0; fi

printf "${YELLOW}==>${NC} Dotfiles: %s   OS: %s%s\n" "$DOTFILES_DIR" "$OS" "$([[ $DRY -eq 1 ]] && echo '   (DRY RUN)')"

# Leak guard: refuse commits containing work-internal paths/URLs (.githooks/pre-commit)
[[ -d "$DOTFILES_DIR/.git" ]] && run git -C "$DOTFILES_DIR" config core.hooksPath .githooks

# ------------------------------------------------------------------------------
# 1. Packages
# ------------------------------------------------------------------------------
install_packages_macos() {
  step "macOS packages (Homebrew)"
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools missing; launching installer. Re-run this script when it finishes."
    run xcode-select --install || true
    exit 1
  fi
  if ! have brew; then
    info "installing" "Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
  fi
  info "brew" "installing ~30 formulae/casks; first run typically 5-15 min (downloads show below)"
  # Never race another brew (a second install.sh, a brew in another window...):
  # concurrent installs fail with "process has already locked .../Cellar/<pkg>".
  while [[ $DRY -eq 0 ]] && pgrep -qf 'Homebrew/brew.rb'; do
    info "waiting" "another brew process is running (pgrep -fl brew); retrying in 15s"
    sleep 15
  done
  # Parallel installs inside brew bundle can still collide on shared deps
  # (e.g. cmake), so retry: each pass only redoes what failed.
  local attempt
  for attempt in 1 2 3; do
    # (only the first pass auto-updates Homebrew)
    if [[ $attempt -gt 1 ]]; then export HOMEBREW_NO_AUTO_UPDATE=1; fi
    if run brew bundle --verbose --file="$DOTFILES_DIR/Brewfile"; then break; fi
    if [[ $attempt -lt 3 ]]; then
      warn "brew bundle pass $attempt had failures (often just lock collisions); retrying..."
      sleep 5
    else
      warn "brew bundle still failing after 3 passes; run: brew bundle --file=$DOTFILES_DIR/Brewfile"
    fi
  done
}

install_packages_linux() {
  step "Linux packages (apt)"
  if ! have apt-get; then warn "apt-get not found; install packages from packages/apt.txt manually"; return 0; fi
  local SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"
  local pkgs=() p
  while read -r p; do
    p="${p%%#*}"; p="$(echo "$p" | tr -d '[:space:]')"
    [[ -z "$p" ]] && continue
    if dpkg -s "$p" >/dev/null 2>&1; then continue; fi
    if apt-cache show "$p" >/dev/null 2>&1; then pkgs+=("$p"); else warn "apt: no package '$p' (skipping)"; fi
  done < "$DOTFILES_DIR/packages/apt.txt"
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    run $SUDO apt-get update -qq
    run $SUDO apt-get install -y "${pkgs[@]}"
  else
    ok "apt" "everything already installed"
  fi
  # fd is called fdfind on Debian/Ubuntu
  if have fdfind && ! have fd; then run mkdir -p "$HOME/.local/bin"; run ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
  # Distro neovim is usually too old for this config: install the official build
  if ! have nvim || ! nvim --headless -c 'if has("nvim-0.11") | qa | else | cq | endif' >/dev/null 2>&1; then
    local arch; arch="$(uname -m)"; [[ "$arch" == "aarch64" ]] && arch="arm64"
    info "installing" "neovim (official release -> ~/.local/nvim)"
    run mkdir -p "$HOME/.local"
    if [[ $DRY -eq 0 ]]; then
      curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz" | tar -xz -C "$HOME/.local"
      rm -rf "$HOME/.local/nvim" && mv "$HOME/.local/nvim-linux-${arch}" "$HOME/.local/nvim"
    fi
    run ln -sf "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"
  fi
}

if [[ $DO_PACKAGES -eq 1 ]]; then
  if [[ "$OS" == "Darwin" ]]; then install_packages_macos; else install_packages_linux; fi
fi

# ------------------------------------------------------------------------------
# 2. Shell / tmux plugin bootstrap (plain git clones -> identical paths everywhere)
# ------------------------------------------------------------------------------
clone() {  # clone <url> <dest>
  if [[ -d "$2/.git" || -d "$2" ]]; then return 0; fi
  info "cloning" "$1 -> ${2/#$HOME/~}"
  run git clone --depth=1 -q "$1" "$2" 2>>"$LOG"
}

if [[ $DO_BOOTSTRAP -eq 1 ]]; then
  step "Shell + tmux plugins"
  have git || { warn "git is required"; exit 1; }
  clone https://github.com/ohmyzsh/ohmyzsh.git                       "$HOME/.oh-my-zsh"
  clone https://github.com/romkatv/powerlevel10k.git                 "$HOME/powerlevel10k"
  clone https://github.com/jeffreytse/zsh-vi-mode.git                "$HOME/.zsh-vi-mode"
  clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$HOME/.zsh/fast-syntax-highlighting"
  clone https://github.com/zsh-users/zsh-autosuggestions.git         "$HOME/.zsh/zsh-autosuggestions"
  clone https://github.com/tmux-plugins/tpm.git                      "$HOME/.tmux/plugins/tpm"
  run mkdir -p "$HOME/.zsh/cache"

  # Default shell -> zsh
  if have zsh && [[ "$(basename "${SHELL:-}")" != "zsh" ]]; then
    info "chsh" "setting default shell to zsh (may prompt for your password)"
    run chsh -s "$(command -v zsh)" || warn "chsh failed; run: chsh -s $(command -v zsh)"
  fi
fi

# ------------------------------------------------------------------------------
# 3. Symlinks
# ------------------------------------------------------------------------------
if [[ $ADOPT -eq 1 ]]; then
  step "Adopting this machine's existing configs into the repo"
  while IFS='|' read -r repo_path target os; do
    os_matches "$os" && adopt "$repo_path" "$HOME/$target"
  done < <(all_entries)
  # Unknown scripts in ~/.local/bin are NOT adopted automatically (too much noise);
  # copy the ones you want into $DOTFILES_DIR/.local/bin by hand.
fi

step "Linking configs"
while IFS='|' read -r repo_path target os; do
  os_matches "$os" && safe_link "$DOTFILES_DIR/$repo_path" "$HOME/$target"
done < <(all_entries)

# ------------------------------------------------------------------------------
# 4. Keyboard: Caps Lock -> Control
# ------------------------------------------------------------------------------
capslock_macos() {
  # hidutil remap (no admin, works for built-in + external keyboards).
  # A LaunchAgent re-applies it at every login.
  local label="com.ollyplance.capslock-to-control"
  local plist="$HOME/Library/LaunchAgents/$label.plist"
  local mapping='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}'
  run mkdir -p "$HOME/Library/LaunchAgents"
  if [[ $DRY -eq 0 ]]; then
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>$mapping</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
  fi
  run launchctl unload "$plist" 2>/dev/null || true
  run launchctl load -w "$plist"
  run /usr/bin/hidutil property --set "$mapping" >/dev/null
  ok "keyboard" "Caps Lock -> Control (hidutil + LaunchAgent $label)"
}

capslock_linux() {
  if have gsettings && gsettings list-keys org.gnome.desktop.input-sources >/dev/null 2>&1; then
    local cur; cur="$(gsettings get org.gnome.desktop.input-sources xkb-options)"
    if [[ "$cur" == *"ctrl:nocaps"* ]]; then
      ok "keyboard" "Caps Lock -> Control already set (GNOME)"
    else
      local new
      if [[ "$cur" == "@as []" || "$cur" == "[]" ]]; then new="['ctrl:nocaps']"; else new="${cur%]}, 'ctrl:nocaps']"; fi
      run gsettings set org.gnome.desktop.input-sources xkb-options "$new"
      ok "keyboard" "Caps Lock -> Control (GNOME xkb-options: $new)"
    fi
  elif have setxkbmap && [[ -n "${DISPLAY:-}" ]]; then
    run setxkbmap -option ctrl:nocaps
    ok "keyboard" "Caps Lock -> Control for this X session (add 'setxkbmap -option ctrl:nocaps' to your session startup to persist)"
  else
    warn "No GNOME/X session detected; skipped Caps Lock remap"
  fi
}

if [[ $DO_KEYBOARD -eq 1 ]]; then
  step "Keyboard"
  if [[ "$OS" == "Darwin" ]]; then capslock_macos; else capslock_linux; fi
fi

# ------------------------------------------------------------------------------
# 5. macOS niceties
# ------------------------------------------------------------------------------
if [[ "$OS" == "Darwin" && $DO_BOOTSTRAP -eq 1 ]]; then
  step "macOS settings"
  if [[ -d /Applications/AeroSpace.app ]] && ! pgrep -xq AeroSpace; then
    run open -a AeroSpace && ok "started" "AeroSpace (grant Accessibility permission when asked)"
  fi
fi

# ------------------------------------------------------------------------------
# 6. Private overlay (e.g. work-only configs that never go to GitHub)
# ------------------------------------------------------------------------------
if [[ -x "$CORP_DIR/install.sh" ]]; then
  step "Private overlay: $CORP_DIR"
  if [[ $DRY -eq 1 ]]; then DRY_RUN=1 "$CORP_DIR/install.sh"; else "$CORP_DIR/install.sh"; fi
else
  info "overlay" "none found at ${CORP_DIR/#$HOME/~} (fine on personal machines)"
fi

# ------------------------------------------------------------------------------
# 7. Machine-local stubs (git-ignored)
# ------------------------------------------------------------------------------
for f in .zshrc.local .tmux.conf.local .gitconfig.local; do
  [[ -e "$HOME/$f" || -L "$HOME/$f" ]] || run touch "$HOME/$f"
done

# ------------------------------------------------------------------------------
# 8. tmux + nvim plugins
# ------------------------------------------------------------------------------
if [[ $DO_BOOTSTRAP -eq 1 && $DRY -eq 0 ]]; then
  step "Installing tmux plugins (TPM)"
  with_heartbeat "TPM" "$HOME/.tmux/plugins/tpm/bin/install_plugins" && ok "tmux" "plugins installed" || warn "TPM install failed; inside tmux press prefix + I"
  if have nvim; then
    step "Installing neovim plugins (lazy.nvim) - may take a minute"
    info "nvim" "cloning ~45 plugins + compiling treesitter parsers; typically 1-5 min"
    with_heartbeat "nvim plugins" nvim --headless "+Lazy! restore" +qa && ok "nvim" "plugins restored from lazy-lock.json" || warn "lazy restore had errors (see $LOG); open nvim and run :Lazy"
    info "nvim" "LSP servers (mason) install in the background the first time you open nvim - see :Mason"
  fi
fi

if [[ $ADOPT -eq 1 ]]; then
  echo
  step "Adopted files are now in the repo. Review them:"
  echo "    cd $DOTFILES_DIR && git status && git diff"
  echo "    keep: git add -p      drop: git checkout -p -- <file>"
fi

printf "${GREEN}==============================================================================${NC}\n"
printf "${GREEN}  DONE in %dm%02ds.${NC} Full log: %s\n" $(( (SECONDS-START)/60 )) $(( (SECONDS-START)%60 )) "$LOG"
printf "${GREEN}  ${NC} Open a new terminal (or: exec zsh). Overrides go in ~/.zshrc.local etc.\n"
printf "${GREEN}==============================================================================${NC}\n"
