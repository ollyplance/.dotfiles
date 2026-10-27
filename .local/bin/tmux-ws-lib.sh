#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# tmux-ws-lib.sh — shared helpers for the tmux workspace scripts in ~/.local/bin
# (sort-tmux, smart-new-tab, workspace-mux, toggle-workspace, ...).
#
# Sourced, not executed:   . "$HOME/.local/bin/tmux-ws-lib.sh" "$@"
#
# Machine-specific extensions live in an optional hook file that is sourced at the
# end of this library (default: ~/.local/bin/tmux-ws-hook.sh, override with
# $TMUX_WS_HOOK). A hook may redefine:
#   ws_special_name PATH  -> echo a workspace name and return 0 if PATH lives inside
#                            a "special" workspace root (e.g. a remote/cloud checkout);
#                            return 1 otherwise. Default: never matches.
#   WS_SPECIAL_PREFIX     -> label prefix for special workspaces (e.g. "Cloud: ")
#   WS_MUX_LABEL_PREFIX   -> label prefix used by workspace-mux for non-~ workspaces
#   WS_KIND_LABEL         -> noun used in picker headers ("Project", ...)
# ==============================================================================

# --- Re-exec under bash >= 4 (associative arrays) — macOS ships bash 3.2 ---
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash /home/linuxbrew/.linuxbrew/bin/bash; do
        if [ -x "$_b" ] && [ "$_b" != "${BASH:-}" ]; then
            exec "$_b" "$0" "$@"
        fi
    done
    echo "$(basename "$0"): needs bash >= 4 (brew install bash)" >&2
    exit 1
fi

WS_SPECIAL_PREFIX="${WS_SPECIAL_PREFIX:-}"
WS_MUX_LABEL_PREFIX="${WS_MUX_LABEL_PREFIX:-}"
WS_KIND_LABEL="${WS_KIND_LABEL:-Project}"

# Default: no special workspace roots (overridden by hook).
ws_special_name() { return 1; }

# Walk up from PATH (within $HOME) looking for a git repo root; echo its basename.
ws_git_root_name() {
    local cur="$1"
    while [[ -n "$cur" && "$cur" != "/" && "$cur" != "$HOME" ]]; do
        if [[ -d "$cur/.git" ]]; then
            echo "${cur##*/}"
            return 0
        fi
        cur="${cur%/*}"
    done
    return 1
}

# Git-aware workspace name: special root > git repo under $HOME > "~" > basename.
ws_resolve_name() {
    local path="$1" name
    if name=$(ws_special_name "$path"); then
        echo "$name"
    elif [[ "$path" == "$HOME"* ]]; then
        ws_git_root_name "$path" || echo "~"
    else
        local base="${path##*/}"
        echo "${base:-/}"
    fi
}

# Simple workspace name (fallback when @workspace_name is unset): special > "~" > basename.
ws_resolve_name_simple() {
    local path="$1" name
    if name=$(ws_special_name "$path"); then
        echo "$name"
    elif [[ "$path" == "$HOME"* ]]; then
        echo "~"
    else
        echo "${path##*/}"
    fi
}

# Portable file mtime (GNU stat, then BSD stat).
ws_file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Portable md5 of a string.
ws_md5() {
    if command -v md5sum >/dev/null 2>&1; then
        printf "%s" "$1" | md5sum | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        printf "%s" "$1" | md5 -q
    else
        printf "%s" "$1" | cksum | cut -d' ' -f1
    fi
}

# Milliseconds since epoch (GNU date supports %N; BSD date does not).
ws_now_ms() {
    local now
    now=$(date +%s%3N 2>/dev/null)
    if [[ -z "$now" || ! "$now" =~ ^[0-9]+$ ]]; then
        now=$(( $(date +%s) * 1000 ))
    fi
    echo "$now"
}

# Deterministic Catppuccin palette for workspace consistency
ws_color() {
    local str="$1"
    local colors=("#89b4fa" "#cba6f7" "#a6e3a1" "#f9e2af" "#fab387" "#94e2d5" "#b4befe")
    local hash=0 i ascii
    for (( i=0; i<${#str}; i++ )); do
        ascii=$(printf "%d" "'${str:$i:1}")
        hash=$(( (hash * 31 + ascii) % ${#colors[@]} ))
    done
    echo "${colors[$hash]}"
}

# jj @ summary for a path: "<rev>\t<OK|CONFLICT>\t<description>" (empty if not a jj repo).
ws_jj_info() {
    local target_path="$1" cur="$1"
    while [[ -n "$cur" && "$cur" != "/" ]]; do
        if [[ -d "$cur/.jj" ]]; then
            (cd "$target_path" 2>/dev/null && jj --no-pager --ignore-working-copy log -r @ --no-graph -T 'change_id.shortest(8) ++ if(empty, "", "*") ++ "\t" ++ if(conflict, "CONFLICT", "OK") ++ "\t" ++ description.first_line()' 2>/dev/null)
            return 0
        fi
        cur="${cur%/*}"
    done
    return 1
}

# Optional machine-specific hook
_ws_hook="${TMUX_WS_HOOK:-$HOME/.local/bin/tmux-ws-hook.sh}"
if [[ -r "$_ws_hook" ]]; then
    # shellcheck source=/dev/null
    . "$_ws_hook"
fi
unset _ws_hook
