# Neovim config

A small IDE-style setup for Neovim 0.12: a file tree, a terminal panel, an
agent panel, tabs, language servers, completion and per-project sessions.
Two plugin repos (mini.nvim and nvim-tree.lua), installed by Neovim's own
`vim.pack`. Plain ASCII throughout, so it works without a Nerd Font.

## Requirements

- Neovim 0.12 or newer, and git
- Optional, used when installed: `ripgrep`, `wl-clipboard` (or `xclip`),
  `clang` (clangd), `pyright`, `ruff`, `lua-language-server`, `gdb`

## Install

```
git clone https://github.com/YOUR-USER/REPO.git ~/.config/nvim
nvim
```

Confirm the plugin install on first start, then press `ZR` to restart.
Plugin versions are pinned in `nvim-pack-lock.json`. To update them, run
`:lua vim.pack.update()`, read the changes, and `:w` to apply.

To try it without touching an existing config, clone it to
`~/.config/nvim-y` and start it with `NVIM_APPNAME=nvim-y nvim`.

## Files

| File | What it does |
|---|---|
| `init.lua` | Options, colors, language servers, completion, finder, git, most keys |
| `plugin/layout.lua` | Tabs, splits, terminal and agent panels |
| `plugin/tree.lua` | File tree sidebar |
| `plugin/projects.lua` | Projects and sessions |

Each file in `plugin/` stands alone: delete it to drop that feature.

## Keys

The leader key is Space. Press it and pause to see what follows.
`<C-x>` means Ctrl+x. Only keys this config adds are listed here; the
built-in ones worth knowing are at the end.

### Files and projects

| Key | Action |
|---|---|
| `<Space>e` | File tree: open, jump to it, or hide it |
| `<Space>E` | File popup: create, rename or move files by editing text |
| `<Space>o` | Open a folder as the project |
| `<Space>fp` | Recent projects |
| `<Space>bd` | Close the current file (never closes Neovim or a panel) |
| `<Space>bo` | Close all other files |

### Find

| Key | Action |
|---|---|
| `<Space>ff` | Files by name |
| `<Space>fg` | Grep, live |
| `<Space>fw` | Grep the word under the cursor |
| `<Space>fb` | Open files |
| `<Space>fo` | Recent files |
| `<Space>fd` | Diagnostics |
| `<Space>fs` / `<Space>fS` | Symbols in this file / in the project |
| `<Space>fh` | Help |
| `<Space>fk` | Keymaps |
| `<Space>fr` | Reopen the last picker |

### Code (when a language server is running)

| Key | Action |
|---|---|
| `gd` / `gD` | Go to definition / declaration |
| `<Space>cf` | Format the file |
| `<Space>ch` | Toggle inlay hints |
| `<Tab>` / `<S-Tab>` | Next / previous completion item or snippet field |
| `<CR>` | Accept the selected completion item |

### Git

| Key | Action |
|---|---|
| `]h` / `[h` | Next / previous changed hunk (`]H` / `[H` last / first) |
| `ghgh` | Stage the hunk under the cursor (`gh` in visual mode for a range) |
| `gHgh` | Undo the hunk under the cursor (discards those edits; `u` brings them back) |
| `<Space>gd` | Show the diff inline |
| `<Space>gh` | List changed hunks |
| `<Space>gl` | Log |
| `<Space>gb` | Blame for this file |

### Layout and panels

| Key | Action |
|---|---|
| `<Space>tt` | Terminal panel: open, jump to it, or hide it |
| `<Space>a` | Agent panel: open, jump to it, or hide it |
| `<Space>z` | Hide all panels and the tree / bring them back |
| `<Space>wv` / `<Space>ws` | Split right / below |
| `<Space>wc` | Close this split (on the last split, just closes its file) |
| `<Space>w=` | Even out split sizes |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move between windows |
| `<Esc><Esc>` | Leave terminal mode (in the terminal panel) |

Panels keep running while hidden. The agent panel runs `claude` if it's
installed; change `agent_cmd` at the top of `plugin/layout.lua` for another
tool.

### Build and tools

| Key | Action |
|---|---|
| `<Space>m` | Build with `:make`; errors go to the quickfix list |
| `<Space>q` | Open the quickfix list |
| `<Space>tu` | Undo tree |
| `<Esc>` | Clear search highlight |

### Mouse

- In the tree, click a folder to open or close it, and click a file to open it.
  Double-clicking does the same.
- Click a tab to switch to it, and middle-click it to close it.
- Click a panel to start typing in it.
- Drag a split border to resize it.

## Inside the tree

Press `g?` for the full list.

| Key | Action |
|---|---|
| `<CR>` | Open |
| `<C-v>` / `<C-x>` | Open in a split right / below |
| `a` | New file (end the name with `/` for a folder) |
| `r` / `d` | Rename / delete |
| `c` / `x` / `p` | Copy / cut / paste |
| `<C-]>` / `-` | Make this folder the project / go up a level |
| `H` / `I` | Show dotfiles / git-ignored files |
| `f` | Filter by name |
| `i` | File info |

## Inside a picker

| Key | Action |
|---|---|
| type | Filter |
| `<C-n>` / `<C-p>` (or arrows) | Move down / up |
| `<CR>` | Open |
| `<C-v>` / `<C-s>` | Open in a split right / below |
| `<Tab>` | Preview |
| `<Esc>` | Close |

## Inside the file popup (`<Space>E`)

Edit the listing as text: rename a line to rename the file, add a line to
create one, delete a line to delete it. Press `=` to apply.

| Key | Action |
|---|---|
| `l` / `h` | Into a folder or open a file / back out |
| `=` | Apply your edits |
| `q` | Close |
| `g?` | Help |

## Commands

| Command | Action |
|---|---|
| `:SessionForget` | Forget the saved session for this project |
| `:Undotree` | Visual undo history |
| `:DiffTool dir1 dir2` | Compare folders or files |
| `:Termdebug ./program` | Debug with gdb in splits |
| `:Git ...` | Run git with output in a split |
| `:Pick ...` | Open any picker by name |
| `:checkhealth` | Check what's installed and working |

## Sessions

Quitting saves the files and splits you had open for the project folder;
opening that folder again (`nvim ~/projects/ws`, `<Space>o` or
`<Space>fp`) brings them back. Quick edits (`nvim somefile`) and plain
`nvim` don't save anything. Session files live in
`~/.local/state/nvim/sessions/`, never inside a project. `:q` on the last
editor window still quits Neovim, as in vim.

## Built into Neovim (not this config, but handy)

| Key | Action |
|---|---|
| `K` | Hover documentation |
| `grn` / `gra` | Rename symbol / code action |
| `grr` / `gri` / `grt` | References / implementation / type definition |
| `gO` | Symbols in this file |
| `<C-s>` | Signature help (insert mode) |
| `]d` / `[d` / `<C-w>d` | Next / previous diagnostic / show it |
| `gcc` / `gc` | Comment a line / a selection |
| `an` / `in` | Grow / shrink the selection by syntax (visual mode) |
| `]b` / `[b` | Next / previous open file |
| `]q` / `[q` | Next / previous quickfix item |
| `ZR` | Restart Neovim |
