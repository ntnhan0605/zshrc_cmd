# dotfiles-sync

Two scripts for moving `~/dotfiles` to another Mac via AirDrop, no git involved.

| Script | Run where | Does |
|---|---|---|
| `pack.sh` | old machine | Tars `~/dotfiles`, encrypts it (AES-256, passphrase typed interactively), drops a `dotfiles-<host>-<timestamp>.tar.gz.enc` on the Desktop, opens Finder on it so you can AirDrop it. |
| `unpack.sh` | new machine | Finds that `.tar.gz.enc` in `~/Downloads`/`~/Desktop` (or takes a path as `$1`), decrypts it with the passphrase you re-enter, extracts to `~/dotfiles` (backing up any existing one first), then offers to run `~/dotfiles/install.sh`. |

Both scripts are self-contained — no shared config, no dependency on where
they live on disk. They're also mirrored standalone (no secrets in the
scripts themselves) at
[`ntnhan0605/zshrc_cmd/dotfiles-sync`](https://github.com/ntnhan0605/zshrc_cmd/tree/main/dotfiles-sync),
so a brand-new Mac can fetch `unpack.sh` before `~/dotfiles` even exists on it:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ntnhan0605/zshrc_cmd/main/dotfiles-sync/unpack.sh)
```

(`bash <(curl ...)` rather than `curl ... | bash`, so the script's passphrase
and confirm prompts still read from your terminal instead of the pipe.)

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
