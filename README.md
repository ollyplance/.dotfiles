# dotfiles

zsh (oh-my-zsh + powerlevel10k + vi-mode), Neovim (lazy.nvim), tmux (+ helper
scripts), kitty, AeroSpace (macOS), git, jj, taskwarrior. Works on macOS and Linux.

## New machine

```bash
# macOS: install git first if needed ->  xcode-select --install
git clone git@github.com:ollyplance/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

`install.sh` does, idempotently:

1. **Packages** – Homebrew + `Brewfile` on macOS, `packages/apt.txt` on Linux
   (plus an up-to-date Neovim if the distro one is too old).
2. **Shell/tmux plugins** – git-clones oh-my-zsh, powerlevel10k, zsh-vi-mode,
   fast-syntax-highlighting, zsh-autosuggestions, TPM; sets zsh as login shell.
3. **Symlinks** – everything in `MANAGED` (top of `install.sh`) + every script
   in `.local/bin`. Existing files are moved to `*.bak.<timestamp>`, never deleted.
4. **Keyboard** – Caps Lock → Control
   (macOS: `hidutil` + a LaunchAgent so it survives reboots;
   Linux/GNOME: `xkb-options ctrl:nocaps`).
5. **Private overlay** – runs `~/.dotfiles-corp/install.sh` if it exists.
6. **Plugins** – TPM plugins and `:Lazy restore` (pinned by `lazy-lock.json`).

Flags: `--adopt`, `--scan`, `--links-only`, `--no-packages`, `--no-keyboard`, `--dry-run`.

## Bringing in configs that only exist on one machine

```bash
./install.sh --scan          # list config files here that the repo doesn't manage
./install.sh --adopt         # copy this machine's existing versions INTO the repo, then link
git diff                     # review; keep with `git add -p`, drop with `git checkout -p`
```

To track something new, copy it into the repo at the same path relative to `$HOME`
and add a line to `MANAGED` in `install.sh` (`repo_path|target|all|Darwin|Linux`).

## Machine-specific / private overrides

Never committed (see `.gitignore`):

| File                 | Loaded by                     |
|----------------------|-------------------------------|
| `~/.zshrc.local`     | end of `.zshrc`               |
| `~/.tmux.conf.local` | end of `.tmux.conf`           |
| `~/.gitconfig.local` | `[include]` in `.gitconfig`   |
| `~/.dotfiles-corp/nvim/lua/corp/` | `lua/config/lazy.lua` (if present) |

A separate, never-pushed `~/.dotfiles-corp` repo can provide all of these (its
`install.sh` symlinks them). A pre-commit hook (`.githooks/`) blocks commits that
look like they contain work-internal paths or URLs.
