#!/usr/bin/env bash
# Generic installer for a ~/dotfiles folder built by dotfiles-sync/collect.sh.
# Everything here is conditional on what actually exists in ~/dotfiles — it
# works the same whether that folder has every category or just one.
# Idempotent: safe to re-run. Existing files are backed up before being
# overwritten.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

backup_then_copy() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
    cp "$dest" "$dest.bak-$(date +%Y%m%d%H%M%S)"
    echo "backed up existing $dest"
  fi
  cp "$src" "$dest"
  echo "wrote $dest"
}

echo "== Homebrew =="
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it first: https://brew.sh"
else
  echo "brew already installed"
fi

echo "== oh-my-zsh =="
if [ -f "$DOTFILES_DIR/zsh/zshrc" ] && [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
elif [ -d "$HOME/.oh-my-zsh" ]; then
  echo "oh-my-zsh already installed"
fi

if [ -s "$DOTFILES_DIR/zsh/extra-clones.txt" ]; then
  echo "== extra zsh clones (prompt themes etc.) =="
  while read -r name url; do
    [ -z "${name:-}" ] && continue
    [[ "$name" == \#* ]] && continue
    target="$HOME/$name"
    if [ ! -d "$target" ]; then
      git clone --depth=1 "$url" "$target"
    else
      echo "$name already installed"
    fi
  done < "$DOTFILES_DIR/zsh/extra-clones.txt"
fi

if [ -s "$DOTFILES_DIR/zsh/custom-plugins.txt" ]; then
  echo "== oh-my-zsh custom plugins =="
  mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
  while read -r name url; do
    [ -z "${name:-}" ] && continue
    [[ "$name" == \#* ]] && continue
    target="$HOME/.oh-my-zsh/custom/plugins/$name"
    if [ ! -d "$target" ]; then
      git clone --depth=1 "$url" "$target"
    else
      echo "$name already installed"
    fi
  done < "$DOTFILES_DIR/zsh/custom-plugins.txt"
fi

if [ -d "$DOTFILES_DIR/zsh" ]; then
  echo "== zsh config files =="
  for f in "$DOTFILES_DIR"/zsh/*; do
    name="$(basename "$f")"
    case "$name" in
      custom-plugins.txt|extra-clones.txt) continue ;;
      zshrc) backup_then_copy "$f" "$HOME/.zshrc" ;;
      p10k.zsh) backup_then_copy "$f" "$HOME/.p10k.zsh" ;;
      *) backup_then_copy "$f" "$HOME/$name" ;;
    esac
  done
fi

if [ -d "$DOTFILES_DIR/ssh" ] && [ -n "$(ls -A "$DOTFILES_DIR/ssh" 2>/dev/null)" ]; then
  echo "== ssh =="
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  for f in "$DOTFILES_DIR"/ssh/*; do
    name="$(basename "$f")"
    backup_then_copy "$f" "$HOME/.ssh/$name"
    case "$name" in
      *.pub|config|known_hosts) chmod 644 "$HOME/.ssh/$name" ;;
      *) chmod 600 "$HOME/.ssh/$name" ;;
    esac
  done
  echo "ssh keys and config restored to ~/.ssh"
fi

if [ -d "$DOTFILES_DIR/claude" ] && [ -n "$(ls -A "$DOTFILES_DIR/claude" 2>/dev/null)" ]; then
  echo "== claude =="
  mkdir -p "$HOME/.claude" "$HOME/.claude/plugins"
  [ -f "$DOTFILES_DIR/claude/settings.json" ] && backup_then_copy "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
  [ -f "$DOTFILES_DIR/claude/settings.local.json" ] && backup_then_copy "$DOTFILES_DIR/claude/settings.local.json" "$HOME/.claude/settings.local.json"
  [ -f "$DOTFILES_DIR/claude/known_marketplaces.json" ] && backup_then_copy "$DOTFILES_DIR/claude/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"
  echo "note: ~/.claude/.credentials.json is NOT managed here — log in again with 'claude /login' on this machine."
fi

if [ -d "$DOTFILES_DIR/git" ] && [ -n "$(ls -A "$DOTFILES_DIR/git" 2>/dev/null)" ]; then
  echo "== git =="
  for f in "$DOTFILES_DIR"/git/*; do
    name="$(basename "$f")"
    case "$name" in
      gitconfig) backup_then_copy "$f" "$HOME/.gitconfig" ;;
      gitignore_global) backup_then_copy "$f" "$HOME/.gitignore_global" ;;
      *) backup_then_copy "$f" "$HOME/.$name" ;;
    esac
  done
  echo "note: any GitHub-token url.insteadOf rules from the old .gitconfig were stripped."
  echo "      run 'gh auth login' then 'gh auth setup-git' instead."
fi

if [ -f "$DOTFILES_DIR/brew/Brewfile" ]; then
  echo "== Homebrew packages =="
  if command -v brew >/dev/null 2>&1; then
    if ! brew bundle install --file="$DOTFILES_DIR/brew/Brewfile"; then
      echo "some Brewfile entries failed — continuing with the rest of install.sh anyway"
      echo "(re-run 'brew bundle install --file=$DOTFILES_DIR/brew/Brewfile' later to retry just that)"
    fi
  else
    echo "Homebrew not available; install it first, then run:"
    echo "    brew bundle install --file=$DOTFILES_DIR/brew/Brewfile"
  fi
fi

if [ -f "$DOTFILES_DIR/vscode/settings.json" ] || [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
  echo "== VS Code =="
  if command -v code >/dev/null 2>&1; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    mkdir -p "$VSCODE_USER_DIR/snippets"
    for f in settings.json keybindings.json mcp.json; do
      [ -f "$DOTFILES_DIR/vscode/$f" ] && backup_then_copy "$DOTFILES_DIR/vscode/$f" "$VSCODE_USER_DIR/$f"
    done
    [ -d "$DOTFILES_DIR/vscode/snippets" ] && rsync -a "$DOTFILES_DIR/vscode/snippets/" "$VSCODE_USER_DIR/snippets/"
    if [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
      while read -r ext; do
        [ -z "$ext" ] && continue
        code --install-extension "$ext" || true
      done < "$DOTFILES_DIR/vscode/extensions.txt"
    fi
  else
    echo "VS Code 'code' CLI not found — install VS Code, enable the 'code' shell command, then re-run this section."
  fi
fi

if [ -f "$DOTFILES_DIR/npm/npmrc" ]; then
  echo "== npm =="
  backup_then_copy "$DOTFILES_DIR/npm/npmrc" "$HOME/.npmrc"
  chmod 600 "$HOME/.npmrc"
fi

if [ -f "$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist" ]; then
  echo "== iTerm2 =="
  if [ -d "/Applications/iTerm.app" ]; then
    defaults import com.googlecode.iterm2 "$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist"
    echo "imported iTerm2 preferences (restart iTerm2 to see them)"
  else
    echo "iTerm2 not installed — install it, then run:"
    echo "    defaults import com.googlecode.iterm2 $DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist"
  fi
fi

if [ -f "$DOTFILES_DIR/nvm/default-node-version" ]; then
  echo "== nvm =="
  echo "note: after opening a new shell (so nvm is loaded), run:"
  echo "    nvm install \$(cat $DOTFILES_DIR/nvm/default-node-version) && nvm alias default \$(cat $DOTFILES_DIR/nvm/default-node-version)"
fi

if [ -f "$DOTFILES_DIR/tailscale/NOTES.md" ]; then
  echo "== Tailscale =="
  cat "$DOTFILES_DIR/tailscale/NOTES.md"
fi

if [ -d "$DOTFILES_DIR/fonts" ] && [ -n "$(ls -A "$DOTFILES_DIR/fonts" 2>/dev/null)" ]; then
  echo "== Fonts =="
  mkdir -p "$HOME/Library/Fonts"
  rsync -a "$DOTFILES_DIR/fonts/" "$HOME/Library/Fonts/"
  echo "installed $(find "$DOTFILES_DIR/fonts" -type f | wc -l | tr -d ' ') font files to ~/Library/Fonts"
fi

echo
echo "Done. Open a new terminal (or 'exec zsh') to pick up the new shell config."
