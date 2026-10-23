#!/usr/bin/env bash
# Packs ~/dotfiles (zsh, ssh incl. private keys, claude, nvm config) into a
# password-encrypted archive on the Desktop, ready to AirDrop to another Mac.
set -euo pipefail

SRC_DIR="$HOME/dotfiles"
TS="$(date +%Y%m%d-%H%M%S)"
HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
OUT="$HOME/Desktop/dotfiles-${HOST}-${TS}.tar.gz.enc"
TMP_TAR="$(mktemp -t dotfiles).tar.gz"

cleanup() { rm -f "$TMP_TAR"; }
trap cleanup EXIT

echo "Packing $SRC_DIR ..."
tar czf "$TMP_TAR" -C "$HOME" dotfiles

echo
echo "Enter a passphrase to encrypt the archive."
echo "You'll need to enter the SAME passphrase on the receiving Mac to decrypt it."
openssl enc -aes-256-cbc -pbkdf2 -salt -in "$TMP_TAR" -out "$OUT"

echo
echo "Done: $OUT"
echo "Opening Finder so you can AirDrop it..."
open -R "$OUT"
