# dotfiles-sync

Two scripts for moving `~/dotfiles` to another Mac via AirDrop, no git involved.

| Script | Run where | Does |
|---|---|---|
| `pack.sh` | old machine | Tars `~/dotfiles`, encrypts it (AES-256, passphrase typed interactively), drops a `dotfiles-<host>-<timestamp>.tar.gz.enc` on the Desktop, opens Finder on it so you can AirDrop it. |
| `unpack.sh` | new machine | Finds that `.tar.gz.enc` in `~/Downloads`/`~/Desktop` (or takes a path as `$1`), decrypts it with the passphrase you re-enter, extracts to `~/dotfiles` (backing up any existing one first), then offers to run `~/dotfiles/install.sh` — and if you say yes, first fixes the common Homebrew failures seen on a fresh Mac before handing off to `install.sh`: stale `/opt/homebrew` download locks (`Permission denied`), a `node`/`llhttp` dyld version mismatch, a leftover `pnpx` binary blocking `corepack`, and taps/casks that are permanently gone upstream (`homebrew/services`, `th-ch/youtube-music`). |

Both scripts are self-contained — no shared config, no dependency on where
they live on disk. They're also mirrored standalone (no secrets in the
scripts themselves) at
[`ntnhan0605/zshrc_cmd/dotfiles-sync`](https://github.com/ntnhan0605/zshrc_cmd/tree/main/dotfiles-sync),
so either script can be fetched and run with one line, without cloning
anything first:

Old machine, if you don't already have `~/dotfiles/dotfiles-sync/pack.sh`:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ntnhan0605/zshrc_cmd/main/dotfiles-sync/pack.sh)
```

New machine, before `~/dotfiles` even exists on it:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ntnhan0605/zshrc_cmd/main/dotfiles-sync/unpack.sh)
```

(`bash <(curl ...)` rather than `curl ... | bash`, so the scripts' passphrase
and confirm prompts still read from your terminal instead of the pipe.) Note
`pack.sh` always reads from `~/dotfiles` on whatever machine it runs on, so
the curl form only makes sense on a machine that already has its own
`~/dotfiles` to pack.

## Usage

Old machine:

```sh
~/dotfiles/dotfiles-sync/pack.sh
```

New machine, after AirDropping the file over:

```sh
~/Downloads/unpack.sh   # or wherever you saved it
```

## What actually goes in the archive

Everything under `~/dotfiles` — see the top-level `README.md` there for what's
included (zsh, ssh incl. private keys, claude, nvm, brew, git, vscode, npm,
iterm2) and why it's safe here but would never be pushed to git.
