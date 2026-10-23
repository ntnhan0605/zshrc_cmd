# dotfiles-sync

A generic toolkit for backing up a Mac's config into `~/dotfiles` and moving
it to another Mac via AirDrop — no git, no account, no secrets ever pushed
anywhere. Works for anyone: nothing here is specific to whoever first wrote
it. Each script only acts on what actually exists on your machine, so it's
fine if you don't have, say, iTerm2 or Tailscale installed.

| Script | Run where | Does |
|---|---|---|
| `collect.sh` | old machine | Scans your live config (zsh, ssh, claude, nvm, brew, git, vscode, npm, iterm2, tailscale — whatever applies) and (re)builds `~/dotfiles` from it. Sanitizes `.gitconfig` (strips any embedded auth tokens) and auto-detects your oh-my-zsh custom plugins / prompt theme clones (powerlevel10k, etc.) from their git remotes. Safe to re-run any time your config changes. |
| `pack.sh` | old machine | Tars `~/dotfiles`, encrypts it (AES-256, passphrase typed interactively), drops a `dotfiles-<host>-<timestamp>.tar.gz.enc` on the Desktop, opens Finder on it so you can AirDrop it. |
| `unpack.sh` | new machine | Finds that `.tar.gz.enc` in `~/Downloads`/`~/Desktop` (or takes a path as `$1`), decrypts it with the passphrase you re-enter, extracts to `~/dotfiles` (backing up any existing one first), then offers to run `~/dotfiles/install.sh` — and if you say yes, first fixes the common Homebrew failures seen on a fresh Mac before handing off to it: stale `/opt/homebrew` download locks (`Permission denied`), a `node`/`llhttp` dyld version mismatch, a leftover `pnpx` binary blocking `corepack`, and taps/casks/formulae that are permanently gone or conflicting upstream (`homebrew/services`, `th-ch/youtube-music`, the standalone `corepack` formula). |
| `install.sh` | new machine | Generic installer bundled into `~/dotfiles` by `collect.sh`. Puts every category it finds back in place (oh-my-zsh + custom plugins + prompt theme, ssh keys, claude settings, Homebrew packages, git config, VS Code settings/extensions, npmrc, iTerm2 prefs) and skips anything that isn't there. Safe to re-run — backs up any existing file before overwriting it, and a failure in one category (e.g. a few Brewfile entries) doesn't stop the rest from running. |

All four are self-contained — no shared config, no dependency on where they
live on disk, no secrets in the scripts themselves (any secrets come only
from *your* `~/dotfiles`, which never leaves your Mac except as the encrypted
AirDrop archive). They're mirrored standalone at
[`ntnhan0605/zshrc_cmd/dotfiles-sync`](https://github.com/ntnhan0605/zshrc_cmd/tree/main/dotfiles-sync),
so any of them can be fetched and run with one line, without cloning
anything first:

Old machine, first time (or to refresh `~/dotfiles` after config changes):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ntnhan0605/zshrc_cmd/main/dotfiles-sync/collect.sh)
```

Old machine, once `~/dotfiles` exists, if you don't already have `pack.sh` locally:

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
its curl form only makes sense on a machine that already has its own
`~/dotfiles` to pack — run `collect.sh` first if it doesn't yet.

## Usage, end to end

Old machine:

```sh
~/dotfiles/dotfiles-sync/collect.sh   # or the curl one-liner above, first time
~/dotfiles/dotfiles-sync/pack.sh
```

New machine, after AirDropping the file over:

```sh
~/Downloads/unpack.sh   # or wherever you saved it
```

## What goes in `~/dotfiles`

Whatever `collect.sh` found on the machine it ran on — typically some subset
of zsh, ssh (including private keys — only safe because this leaves the
machine exclusively as an encrypted AirDrop archive, never via git), claude,
nvm, brew, git (sanitized), vscode, npm, iterm2. `collect.sh` prints what it
picked up as it runs. `install.sh` puts back only what it finds — if your
`~/dotfiles` has no `brew/Brewfile`, it just skips that section.

## Updating `~/dotfiles` after changing config on the old machine

```sh
~/dotfiles/dotfiles-sync/collect.sh
```

Re-running it always takes a fresh snapshot of your current live config —
no need to edit anything in `~/dotfiles` by hand.
