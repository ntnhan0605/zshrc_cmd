#!/usr/bin/env bash
# Scans this Mac's live config and (re)builds ~/dotfiles from it, ready for
# dotfiles-sync/pack.sh to encrypt and AirDrop to another Mac. Safe to re-run
# any time your config changes — always overwrites ~/dotfiles with a fresh
# snapshot. Only ever writes to ~/dotfiles; never touches your live config.
#
# What it looks for is all optional — nothing here errors out just because
# you don't have, say, iTerm2 or Tailscale installed.
set -euo pipefail

DOTFILES="$HOME/dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DOTFILES"/{zsh,ssh,claude,nvm,brew,git,vscode/snippets,npm,iterm2,tailscale,dotfiles-sync}
echo ".DS_Store" > "$DOTFILES/.gitignore"

echo "== zsh =="
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$DOTFILES/zsh/zshrc"
[ -f "$HOME/.p10k.zsh" ] && cp "$HOME/.p10k.zsh" "$DOTFILES/zsh/p10k.zsh"

: > "$DOTFILES/zsh/custom-plugins.txt"
if [ -d "$HOME/.oh-my-zsh/custom/plugins" ]; then
  for d in "$HOME/.oh-my-zsh/custom/plugins"/*/; do
    [ -d "${d}.git" ] || continue
    name="$(basename "$d")"
    url="$(git -C "$d" remote get-url origin 2>/dev/null)" || continue
    echo "$name $url" >> "$DOTFILES/zsh/custom-plugins.txt"
  done
fi

: > "$DOTFILES/zsh/extra-clones.txt"
for d in "$HOME"/*/; do
  name="$(basename "$d")"
  case "$name" in
    powerlevel10k|pure|spaceship-prompt|starship) ;;
    *) continue ;;
  esac
  [ -d "${d}.git" ] || continue
  url="$(git -C "$d" remote get-url origin 2>/dev/null)" || continue
  echo "$name $url" >> "$DOTFILES/zsh/extra-clones.txt"
done

# Any top-level helper script your .zshrc sources directly (e.g. `source ~/foo.sh`)
if [ -f "$HOME/.zshrc" ]; then
  while read -r script; do
    [ -f "$HOME/$script" ] || continue
    cp "$HOME/$script" "$DOTFILES/zsh/$script"
  done < <(grep -oE '(source|\.) +(\"\$\{?HOME\}?|~)/[A-Za-z0-9._-]+\.sh' "$HOME/.zshrc" 2>/dev/null | grep -oE '[A-Za-z0-9._-]+\.sh$' | sort -u)
fi

echo "== ssh =="
if [ -d "$HOME/.ssh" ]; then
  rsync -a --exclude='.DS_Store' --exclude='agent' --exclude='known_hosts.old' "$HOME/.ssh/" "$DOTFILES/ssh/"
  chmod 700 "$DOTFILES/ssh"
  find "$DOTFILES/ssh" -maxdepth 1 -type f ! -name '*.pub' ! -name 'config' ! -name 'known_hosts' -exec chmod 600 {} \;
  echo "included private keys — this is fine ONLY because ~/dotfiles leaves this Mac exclusively as an encrypted AirDrop archive, never via git"
fi

echo "== claude =="
if [ -d "$HOME/.claude" ]; then
  [ -f "$HOME/.claude/settings.json" ] && cp "$HOME/.claude/settings.json" "$DOTFILES/claude/settings.json"
  [ -f "$HOME/.claude/settings.local.json" ] && cp "$HOME/.claude/settings.local.json" "$DOTFILES/claude/settings.local.json"
  [ -f "$HOME/.claude/plugins/known_marketplaces.json" ] && cp "$HOME/.claude/plugins/known_marketplaces.json" "$DOTFILES/claude/known_marketplaces.json"
fi

echo "== nvm =="
[ -f "$HOME/.nvm/alias/default" ] && cp "$HOME/.nvm/alias/default" "$DOTFILES/nvm/default-node-version"

echo "== Homebrew =="
if command -v brew >/dev/null 2>&1; then
  brew bundle dump --file="$DOTFILES/brew/Brewfile" --force
fi

echo "== git =="
sanitize_gitconfig() {
  # Drop any [url "..."] block whose header embeds a credential
  # (scheme://user-or-token@...), and strip stray PAT-looking strings left
  # over in comments. Generic safety net — don't ship auth tokens in a
  # gitconfig to anyone, even over an AirDrop-only channel.
  awk '
    /^\[url "[a-zA-Z]+:\/\/[^"]*@/ { skip=1; next }
    skip==1 && /^\[/ { skip=0 }
    skip==1 { next }
    /ghp_[A-Za-z0-9]{20,}/ { next }
    /github_pat_[A-Za-z0-9_]{20,}/ { next }
    /gho_[A-Za-z0-9]{20,}/ { next }
    { print }
  ' "$1"
}

if [ -f "$HOME/.gitconfig" ]; then
  sanitize_gitconfig "$HOME/.gitconfig" > "$DOTFILES/git/gitconfig"
  while read -r inc_path; do
    inc_expanded="${inc_path/#\~/$HOME}"
    [ -f "$inc_expanded" ] || continue
    sanitize_gitconfig "$inc_expanded" > "$DOTFILES/git/$(basename "$inc_expanded")"
  done < <(awk '/^\[includeIf/{f=1} f && /path *=/{print $3; f=0}' "$HOME/.gitconfig")

  excludesfile="$(git config --global --get core.excludesfile 2>/dev/null || true)"
  excludesfile_expanded="${excludesfile/#\~/$HOME}"
  if [ -n "$excludesfile_expanded" ] && [ -f "$excludesfile_expanded" ]; then
    cp "$excludesfile_expanded" "$DOTFILES/git/gitignore_global"
  fi
fi

echo "== VS Code =="
if command -v code >/dev/null 2>&1; then
  VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
  for f in settings.json keybindings.json mcp.json; do
    [ -f "$VSCODE_USER_DIR/$f" ] && cp "$VSCODE_USER_DIR/$f" "$DOTFILES/vscode/$f"
  done
  [ -d "$VSCODE_USER_DIR/snippets" ] && rsync -a "$VSCODE_USER_DIR/snippets/" "$DOTFILES/vscode/snippets/"
  code --list-extensions > "$DOTFILES/vscode/extensions.txt"
fi

echo "== npm =="
if [ -f "$HOME/.npmrc" ]; then
  cp "$HOME/.npmrc" "$DOTFILES/npm/npmrc"
  chmod 600 "$DOTFILES/npm/npmrc"
  echo "included ~/.npmrc as-is — may contain real registry auth tokens; same AirDrop-only reasoning as ssh/"
fi

echo "== iTerm2 =="
if [ -d "/Applications/iTerm.app" ]; then
  defaults export com.googlecode.iterm2 "$DOTFILES/iterm2/com.googlecode.iterm2.plist"
fi

echo "== Tailscale =="
if command -v tailscale >/dev/null 2>&1; then
  cat > "$DOTFILES/tailscale/NOTES.md" <<'EOF'
# Tailscale

Not synced as a file — Tailscale's device identity/auth key is
machine-specific, and copying it would let the new machine impersonate this
one on the tailnet. On the new Mac, just:

```sh
brew install tailscale
sudo tailscale up
```

and authenticate with your Tailscale account when prompted.
EOF
fi

echo "== dotfiles-sync tooling (so the archive is self-contained) =="
cp "$SCRIPT_DIR/pack.sh" "$DOTFILES/dotfiles-sync/pack.sh"
cp "$SCRIPT_DIR/unpack.sh" "$DOTFILES/dotfiles-sync/unpack.sh"
cp "$SCRIPT_DIR/README.md" "$DOTFILES/dotfiles-sync/README.md"
cp "$SCRIPT_DIR/install.sh" "$DOTFILES/install.sh"
chmod +x "$DOTFILES/dotfiles-sync/pack.sh" "$DOTFILES/dotfiles-sync/unpack.sh" "$DOTFILES/install.sh"

echo
echo "Done. ~/dotfiles is ready — run ~/dotfiles/dotfiles-sync/pack.sh to AirDrop it."
