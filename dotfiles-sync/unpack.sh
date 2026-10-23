#!/usr/bin/env bash
# Decrypts + extracts a dotfiles-*.tar.gz.enc archive made by pack.sh, then
# optionally runs install.sh. Run this on the NEW Mac after AirDropping the
# file over (it usually lands in ~/Downloads).
set -euo pipefail

ENC_FILE="${1:-}"

if [ -z "$ENC_FILE" ]; then
  candidates=()
  for d in "$HOME/Downloads" "$HOME/Desktop" "$HOME"; do
    for f in "$d"/dotfiles-*.tar.gz.enc; do
      [ -e "$f" ] && candidates+=("$f")
    done
  done
  if [ "${#candidates[@]}" -eq 1 ]; then
    ENC_FILE="${candidates[0]}"
  elif [ "${#candidates[@]}" -gt 1 ]; then
    echo "Found multiple archives, pass the one to use explicitly:"
    printf '  %s\n' "${candidates[@]}"
    exit 1
  else
    echo "Usage: $0 <path-to-dotfiles-*.tar.gz.enc>"
    exit 1
  fi
fi

echo "Using archive: $ENC_FILE"
TMP_TAR="$(mktemp -t dotfiles).tar.gz"
cleanup() { rm -f "$TMP_TAR"; }
trap cleanup EXIT

echo "Enter the passphrase used when packing:"
openssl enc -d -aes-256-cbc -pbkdf2 -in "$ENC_FILE" -out "$TMP_TAR"

if [ -d "$HOME/dotfiles" ]; then
  mv "$HOME/dotfiles" "$HOME/dotfiles.bak-$(date +%Y%m%d%H%M%S)"
  echo "backed up existing ~/dotfiles"
fi

tar xzf "$TMP_TAR" -C "$HOME"
echo "extracted to ~/dotfiles"

fix_homebrew() {
  command -v brew >/dev/null 2>&1 || return 0
  echo "Pre-flight: fixing common Homebrew permission/dyld issues..."
  local brew_prefix
  brew_prefix="$(brew --prefix)"
  sudo rm -f "$brew_prefix"/var/homebrew/locks/*.lock 2>/dev/null || true
  sudo chown -R "$(whoami)":admin "$brew_prefix" 2>/dev/null || true
  # Fixes "Library not loaded: .../libllhttp.*.dylib" from node/llhttp version drift
  brew reinstall llhttp node 2>/dev/null || true
  # Fixes "npm error EEXIST .../pnpx" blocking corepack's reinstall
  rm -f "$brew_prefix/bin/pnpx" 2>/dev/null || true
  # Drop taps/casks that are permanently gone upstream (not fixable, just noise)
  local brewfile="$HOME/dotfiles/brew/Brewfile"
  if [ -f "$brewfile" ]; then
    sed -i '' \
      -e '/^tap "homebrew\/services"$/d' \
      -e '/^tap "th-ch\/youtube-music"$/d' \
      -e '/^cask "youtube-music"$/d' \
      "$brewfile" 2>/dev/null || true
  fi
}

read -r -p "Run ~/dotfiles/install.sh now? [y/N] " yn || yn="n"
case "$yn" in
  [Yy]*)
    fix_homebrew
    exec "$HOME/dotfiles/install.sh"
    ;;
  *) echo "Skipped. Run ~/dotfiles/install.sh manually when ready." ;;
esac
