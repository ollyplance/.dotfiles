export PATH="$HOME/.local/bin:$PATH"
################################################################################
# 1. POWERLEVEL10K INSTANT PROMPT (Must stay at the top)
################################################################################
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Disable Oh My Zsh auto-update checks
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"


################################################################################
# 2. ENVIRONMENT VARIABLES & PATHS
################################################################################
# Homebrew (macOS): put brew on PATH before anything else looks for tools
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export ZSH="$HOME/.oh-my-zsh"
export EDITOR=nvim
export VISUAL=nvim
export HISTFILE=~/.histfile
export HISTSIZE=10000
export SAVEHIST=$HISTSIZE

# Path updates
command -v go >/dev/null 2>&1 && export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
export PATH="$PATH:$HOME/.local/bin"

################################################################################
# 3. OH-MY-ZSH BASE
################################################################################
plugins=(git kubectl)
[[ -f $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh

################################################################################
# 4. SHELL OPTIONS & COMPLETION
################################################################################
zstyle ':completion:*' menu yes select
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path ~/.zsh/cache
zstyle ':completion:*' users root $USER
# Optimized compinit loading
autoload -Uz compinit
if [[ -n $(find ~/.zcompdump -mmin +1200 2>/dev/null) ]]; then
  compinit -i
else
  compinit -C -i
fi

setopt appendhistory
setopt share_history

################################################################################
# 5. PLUGINS CONFIGURATION (The "Engine" room)
################################################################################
# All plugins are git-cloned into ~/.zsh / $HOME by install.sh, so paths are the
# same on macOS and Linux.

# ZSH Vi Mode Config (Crucial for paste speed)
function zvm_config() {
  ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
  ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
  # Use ZLE engine for faster key processing
  ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE
}
[[ -f $HOME/.zsh-vi-mode/zsh-vi-mode.plugin.zsh ]] && source $HOME/.zsh-vi-mode/zsh-vi-mode.plugin.zsh

# Bind backspace correctly after zsh-vi-mode initializes
function zvm_after_init() {
  bindkey '^?' backward-delete-char
  bindkey '^H' backward-delete-char
}

# Autosuggestions (Limit buffer to prevent lag on long pastes)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
for f in ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f $f ]] && { source $f; break; }
done

# Fast Syntax Highlighting
[[ -f ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] && source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
ZSH_HIGHLIGHT_MAXLENGTH=512

# JJ Plugin
# [[ -f ~/.zsh/zsh-jj/zsh-jj.plugin.zsh ]] && source ~/.zsh/zsh-jj/zsh-jj.plugin.zsh

################################################################################
# 6. UTILITIES & FZF
################################################################################
if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  # Debian/Ubuntu packaged fzf
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
elif command -v fzf >/dev/null 2>&1 && fzf --zsh >/dev/null 2>&1; then
  # fzf >= 0.48 (Homebrew)
  source <(fzf --zsh)
fi

# Kubernetes helpers (kuse / kctx / kns + per-tmux-pane kubeconfig isolation)
[[ -f ~/.config/zsh/kube.zsh ]] && source ~/.config/zsh/kube.zsh

################################################################################
# 7. PROMPT & THEMING
################################################################################
if [[ -f ~/powerlevel10k/powerlevel10k.zsh-theme ]]; then
  source ~/powerlevel10k/powerlevel10k.zsh-theme
fi

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

################################################################################
# 8. ALIASES
################################################################################
if ls --color=auto / >/dev/null 2>&1; then
  alias ls="ls --color"   # GNU ls
else
  alias ls="ls -G"        # BSD ls (macOS)
fi
alias la="ls -la"
alias ll="ls -ll"
alias less="less -R"
alias n="nvim ."
alias kjobctl="kubectl kjob"

# Custom AI Clipboard utility to copy LAST code block instantly
alias cac='~/.local/bin/copy-ai-code'

################################################################################
# 9. LOCAL & ENV OVERRIDES (Git-Ignored)
################################################################################
# Automatically inject workspace or workstation specific configurations securely
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Automatically update tmux workspace grouping and colors on directory change
if [[ -n "$TMUX" ]]; then
  chpwd_tmux_workspace() {
    tmux run-shell -b "~/.local/bin/sort-tmux"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd chpwd_tmux_workspace

  # Workspace-aware tab creator (spawns sibling tab next to current tab)
  nt() {
    ~/.local/bin/smart-new-tab "${1:-$PWD}"
  }
  alias tab=nt
fi

################################################################################
# 10. THE "MAGIC" FIX (Must be the absolute last lines of the file)
################################################################################
# Load bracketed-paste-magic
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# Also load url-quote-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# Force bind the paste escape sequence to the magic widget
bindkey '^[[200~' bracketed-paste

# Lazy-load NVM
declare -a __node_commands=('nvm' 'node' 'npm' 'npx' 'yarn' 'pnpm')
function __init_nvm() {
  for cmd in "${__node_commands[@]}"; do
    unfunction "$cmd"
  done
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
for cmd in "${__node_commands[@]}"; do
  eval "function $cmd() { __init_nvm; $cmd \"\$@\"; }"
done
