# halcyon Python packages

Staged into the image at build time by `recipes/modules/build-scripts.yml`
(→ `/usr/src/python-packages`) and installed by
`files/scripts/install-python-packages.sh` into one shared venv at
`/usr/lib/halcyon-python`. Every console script is symlinked separately into
`/usr/bin`, so each tool is its own binary on PATH. All packages are
stdlib-only (zero pip dependencies) and build-verified by
`build-scripts-verify.sh`.

| Package | Binary | Purpose |
| --- | --- | --- |
| `dump-to-markdown` | `dump-to-markdown` | Dump a project tree into one Markdown document (headings + fenced code blocks). |
| `fconf` | `fconf` | Fuzzy configuration finder/editor (fd \| fzf \| bat \| `$EDITOR`). |
| `fe` | `fe` | Fuzzy edit — pick a file with fd/fzf, open in `$EDITOR`. |
| `ff` | `ff` | Fast file finder wrapping `fd` with a `find` fallback. |
| `fkill` | `fkill` | Fuzzy process killer (`ps` \| fzf, SIGTERM/SIGKILL). |
| `fp` | `fp` | Fuzzy file/directory previewer (fd \| fzf, composable stdout). |
| `fssh` | `fssh` | Fuzzy SSH launcher driven by `~/.ssh/config`. |
| `rmi` | `rmi` | Safe removal to the XDG trash with collision handling. |
| `rmtmp` | `rmtmp` | Root-only secure cleanup of old files in `/tmp` and `/var/tmp`. |
| `screenshot` | `screenshot` | Wayland screenshot helper (`grim` \| swappy; slurp region, niri window). |
| `se` | `se` | Search & edit — ripgrep \| fzf \| `$EDITOR` at the matched line. |

Runtime tool dependencies (`fd`, `fzf`, `bat`, `rg`, `grim`, `swappy`, `slurp`)
are provided by the image's RPM layer; each tool checks for its own
dependencies at startup and exits with a clear message if missing.

## Development

Each directory is a standalone src-layout package. From this repo:

```sh
python3 -m venv .venv && .venv/bin/pip install -e './dump-to-markdown[dev]'
.venv/bin/pytest dump-to-markdown   # package with a test suite
```

The same install command pattern works for any package
(`pip install -e './<name>'`).
