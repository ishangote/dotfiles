# WezTerm key bindings

Everything here was read off this machine with `wezterm show-keys`, not from the
docs. Re-verify any of it the same way. WezTerm at the time of writing:
`20240203-110809-5046fc22`.

Anything not marked **custom** is a WezTerm macOS default.

## Custom - from `home/.config/wezterm/wezterm.lua`

| Key | Does |
| --- | --- |
| `Opt` + `←` / `→` | Move by word (sends `ESC-b` / `ESC-f`) |
| `Cmd` + `←` / `→` | Start / end of line (sends `Ctrl-A` / `Ctrl-E`) |
| `Cmd` + `C` / `Cmd` + `V` | Copy / paste |
| `Cmd` + `D` | Split - new pane to the right |
| `Cmd` + `Shift` + `D` | Split - new pane below |
| `Cmd` + `Shift` + `W` | Close pane (with confirm) |
| `Cmd` + `Opt` + arrows | Move focus between panes |
| `Cmd` + click | Open link under cursor |

Selecting text does **not** copy. See the copy-on-select section of the README
for why that takes six `Nop` bindings rather than one setting.

## Discovery

| Key | Does |
| --- | --- |
| `Ctrl` + `Shift` + `P` | Command palette. Every action with its binding, searchable. |

## Tabs

| Key | Does |
| --- | --- |
| `Cmd` + `T` | New tab |
| `Cmd` + `W` | Close tab, and every pane in it (with confirm) |
| `Cmd` + `1` … `Cmd` + `8` | Jump to tab N |
| `Cmd` + `9` | Jump to last tab |
| `Cmd` + `Shift` + `[` / `]` | Previous / next tab |
| `Ctrl` + `Tab` / `Ctrl` + `Shift` + `Tab` | Previous / next tab |
| `Ctrl` + `PageUp` / `PageDown` | Previous / next tab |
| `Ctrl` + `Shift` + `PageUp` / `PageDown` | Move tab left / right |
| `Cmd` + `N` | New window |

`hide_tab_bar_if_only_one_tab` is on, so the tab bar only appears at the first
`Cmd+T`.

## Panes

The custom `Cmd`-based bindings above are the ones to use. These defaults remain:

| Key | Does |
| --- | --- |
| `Ctrl` + `Shift` + arrows | Move focus between panes |
| `Ctrl` + `Shift` + `Opt` + arrows | Resize pane |
| `Ctrl` + `Shift` + `Z` | Zoom pane to fill the tab (toggle) |
| `Ctrl` + `Shift` + `Opt` + `'` | Split top/bottom |
| `Ctrl` + `Shift` + `Opt` + `5` | Split left/right |

## Scrollback, search, copy

| Key | Does |
| --- | --- |
| `Shift` + `PageUp` / `PageDown` | Scroll a page |
| `Cmd` + `F` | Search scrollback |
| `Cmd` + `K` | Clear scrollback |
| `Ctrl` + `Shift` + `X` | Enter copy mode |
| `Ctrl` + `Shift` + `Space` | Quick select |

**Copy mode** (`Ctrl+Shift+X`) - `h/j/k/l` or arrows to move, `w`/`b`/`e` by
word, `0`/`^`/`$` for line ends, `g`/`G` for scrollback top/bottom, `H`/`M`/`L`
for viewport top/middle/bottom, `Ctrl+u`/`Ctrl+d` half page, `Ctrl+b`/`Ctrl+f`
full page, `f`/`F`/`t`/`T` to jump to a character with `;`/`,` to repeat. `v`
starts a cell selection, `V` a line selection, `Ctrl+v` a block selection, `o`
jumps to the other end. `y` yanks and exits. `q`, `Esc`, `Ctrl+c` or `Ctrl+g`
exit without copying.

**Quick select** (`Ctrl+Shift+Space`) - labels every URL, path, hash and IP on
screen with a letter. Type the letter to copy it. No mouse needed.

**Search** (`Cmd+F`) - `Ctrl+n` / `Ctrl+p` cycle matches (arrows work too),
`PageUp` / `PageDown` jump by page, `Ctrl+r` cycles match type (case-sensitive /
case-insensitive / regex), `Ctrl+u` clears the pattern, `Esc` exits.

## Misc

| Key | Does |
| --- | --- |
| `Cmd` + `=` / `-` / `0` | Font size up / down / reset |
| `Opt` + `Enter` | Toggle fullscreen |
| `Cmd` + `R` | Reload config (it auto-reloads on save anyway) |
| `Cmd` + `M` | Minimize |
| `Cmd` + `H` | Hide application |
| `Cmd` + `Q` | Quit |
| `Ctrl` + `Shift` + `U` | Character / emoji picker |
| `Ctrl` + `Shift` + `L` | Debug overlay |

## Two gotchas when reading `show-keys` output

Every `Ctrl+Shift+<letter>` binding needs the Shift. Plain `Ctrl+C` still sends
SIGINT and `Ctrl+Z` still suspends - WezTerm stays out of the shell's way.

`show-keys` prints the same physical chord twice, as `CTRL <uppercase>` and
`SHIFT | CTRL <uppercase>`. Those are one binding, not two. Same for `SUPER d`
vs `SUPER D`, which really are different chords (`Cmd+D` vs `Cmd+Shift+D`) - read
the case carefully.
