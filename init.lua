-- ~/.config/nvim/init.lua
--
-- A small IDE-style Neovim config, built the same way as the st "y build":
-- start from upstream, add only what earns its place, keep every step visible.
--
-- Target: Neovim 0.12.x (Arch `extra`). One plugin repo (mini.nvim); everything
-- else below is built into Neovim. Read it top to bottom; each numbered section
-- stands on its own, so you can delete one without breaking the others.
--
-- This file is the core. Extra features live one per file in
-- ~/.config/nvim/plugin/ (Neovim sources those automatically, in alphabetical
-- order, right after this file). Delete a file there to remove that feature.
--
-- External programs it uses when present (all from pacman, no Mason, no npm):
--   ripgrep               live grep in the picker
--   wl-clipboard          system clipboard (your st has OSC 52 off, so Neovim
--                         needs a real clipboard tool; xclip works too)
--   clang                 provides clangd for C/C++
--   pyright, ruff         Python type checking, lint and format
--   lua-language-server   for editing this file
--   gdb                   debugger, through the built-in :Termdebug
-- Anything missing is skipped quietly.
--
-- Built-in keys you get for free once a language server attaches (0.11/0.12):
--   K hover   grn rename   gra code action   grr references
--   gri implementation   grt type definition   gO document symbols
--   <C-s> signature help (insert)   [d ]d next/prev diagnostic
--   <C-w>d diagnostic float   an / in (visual) grow/shrink selection
--   gc / gcc comment   [q ]q quickfix   ZR restart Neovim

---------------------------------------------------------------------------
-- 0. Leader (must come before any mapping that uses it)
---------------------------------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local aug = vim.api.nvim_create_augroup('y_config', { clear = true })
local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

---------------------------------------------------------------------------
-- 1. Options
---------------------------------------------------------------------------
local o = vim.o
o.number = true
o.relativenumber = true
o.signcolumn = 'yes'          -- always reserve the gutter so text doesn't shift
o.cursorline = true
o.termguicolors = true        -- st does 24-bit color
o.background = 'dark'
o.scrolloff = 8
o.wrap = false
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.inccommand = 'split'        -- live preview of :s/// in a split
o.undofile = true             -- undo history survives restarts (see :Undotree)
o.updatetime = 250
o.confirm = true              -- ask instead of failing on :q with unsaved work
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.list = true
o.listchars = 'tab:> ,trail:-,nbsp:+'  -- plain ASCII, renders in Liberation Mono
o.clipboard = 'unnamedplus'   -- y/p use the system clipboard
o.foldlevelstart = 99         -- folds exist but start open
o.winborder = 'single'        -- borders on hover/diagnostic floats
o.pumborder = 'single'        -- and on the completion menu (0.12)
o.exrc = true                 -- per-project .nvim.lua; 0.12 makes you :trust it first

-- Experimental in 0.12: new message/cmdline UI, no more "Press ENTER" prompts.
-- require('vim._core.ui2').enable()

---------------------------------------------------------------------------
-- 2. Colors
---------------------------------------------------------------------------
-- retrobox ships with Neovim and is gruvbox-flavored, so it matches your st
-- palette without a plugin. The autocmd clears the background on the main
-- groups: st's alpha patch only makes the *default* background translucent,
-- so a colorscheme that paints its own background would make nvim opaque.
-- Set this to false if you'd rather have a solid background.
local transparent = true

vim.api.nvim_create_autocmd('ColorScheme', {
  group = aug,
  callback = function()
    if not transparent then return end
    for _, name in ipairs({ 'Normal', 'NormalNC', 'SignColumn', 'EndOfBuffer', 'FoldColumn' }) do
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      hl.bg, hl.ctermbg = nil, nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end,
})
vim.cmd.colorscheme('retrobox')

---------------------------------------------------------------------------
-- 3. Plugins (built-in vim.pack)
---------------------------------------------------------------------------
-- First start asks you to confirm the install; read it, then accept.
-- Pinned revisions land in ~/.config/nvim/nvim-pack-lock.json. Commit that
-- file next to init.lua, like your st patch list.
-- Update later with :lua vim.pack.update()  (shows a diff; :w applies, :q aborts)
vim.pack.add({
  -- One repo, no dependencies, each module standalone. Tracks the newest
  -- release tag instead of the main branch.
  { src = 'https://github.com/nvim-mini/mini.nvim', version = vim.version.range('*') },
})

-- Fuzzy finder (files, grep, buffers, help...) + extra pickers (LSP, diagnostics)
require('mini.pick').setup()
require('mini.extra').setup()

-- File operations popup (<Space>E): edit the listing like text, press = to
-- apply. It's not the folder handler, so `nvim somefolder` opens only the
-- sidebar tree from plugin/tree.lua.
require('mini.files').setup({
  windows = { preview = true, width_preview = 50 },
  options = { use_as_default_explorer = false },
})

-- Git: change markers in the gutter, hunk navigation ([h ]h), :Git command
require('mini.diff').setup({
  view = { style = 'sign', signs = { add = '+', change = '~', delete = '-' } },
})
require('mini.git').setup()

-- Key hints: pause after <leader>, g, [, ], z or <C-w> to see what's available
local clue = require('mini.clue')
clue.setup({
  triggers = {
    { mode = 'n', keys = '<Leader>' }, { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' },        { mode = 'x', keys = 'g' },
    { mode = 'n', keys = '[' },        { mode = 'n', keys = ']' },
    { mode = 'n', keys = 'z' },        { mode = 'x', keys = 'z' },
    { mode = 'n', keys = '<C-w>' },
    { mode = 'n', keys = '"' },        { mode = 'n', keys = "'" },
  },
  clues = {
    { mode = 'n', keys = '<Leader>f', desc = '+find' },
    { mode = 'n', keys = '<Leader>c', desc = '+code' },
    { mode = 'n', keys = '<Leader>g', desc = '+git' },
    { mode = 'n', keys = '<Leader>t', desc = '+terminal/tools' },
    { mode = 'n', keys = '<Leader>w', desc = '+windows' },
    { mode = 'n', keys = '<Leader>b', desc = '+buffers' },
    clue.gen_clues.g(),
    clue.gen_clues.square_brackets(),
    clue.gen_clues.z(),
    clue.gen_clues.windows(),
    clue.gen_clues.registers(),
    clue.gen_clues.marks(),
  },
  window = { delay = 400 },
})

-- Built-in optional plugins (shipped with Neovim, off until added)
vim.cmd('packadd! nvim.undotree')   -- :Undotree
vim.cmd('packadd! nvim.difftool')   -- :DiffTool dirA dirB
vim.cmd('packadd! termdebug')       -- :Termdebug ./program  (gdb in splits)

---------------------------------------------------------------------------
-- 4. Language servers (built-in vim.lsp; no nvim-lspconfig needed)
---------------------------------------------------------------------------
-- Each block is the whole definition: the command to run, which filetypes it
-- serves, and which files mark a project root.
vim.lsp.config('clangd', {
  cmd = { 'clangd', '--background-index', '--clang-tidy', '--header-insertion=never' },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  root_markers = { 'compile_commands.json', '.clangd', '.git' },
})

vim.lsp.config('pyright', {
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
  settings = { python = { analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true } } },
})

vim.lsp.config('ruff', {
  cmd = { 'ruff', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
})

vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.git' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      -- Knows the `vim.*` API, so editing this file gets completion too
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
    },
  },
})

-- Only enable servers whose binary is installed, so a missing one stays silent.
local servers = {
  clangd = 'clangd',
  pyright = 'pyright-langserver',
  ruff = 'ruff',
  lua_ls = 'lua-language-server',
}
for name, exe in pairs(servers) do
  if vim.fn.executable(exe) == 1 then vim.lsp.enable(name) end
end

-- Per-buffer setup when a server attaches
vim.api.nvim_create_autocmd('LspAttach', {
  group = aug,
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    local buf = ev.buf
    local function bmap(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc })
    end

    bmap('gd', vim.lsp.buf.definition, 'Go to definition')
    bmap('gD', vim.lsp.buf.declaration, 'Go to declaration')
    bmap('<leader>cf', function() vim.lsp.buf.format({ async = true }) end, 'Format file')
    bmap('<leader>ch', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
    end, 'Toggle inlay hints')

    -- Lets <C-y>/<CR> on a completion item apply its extras
    -- (snippet expansion, auto-imports).
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, buf)
    end

    -- pyright and ruff both answer hover; keep pyright's (types + docs)
    if client.name == 'ruff' then
      client.server_capabilities.hoverProvider = false
    end
  end,
})

---------------------------------------------------------------------------
-- 5. Completion (built-in, as-you-type, 0.12 'autocomplete')
---------------------------------------------------------------------------
-- Sources in order: o = language server (via omnifunc), then words from this
-- buffer, other windows, other buffers.
o.autocomplete = true
o.complete = 'o,.,w,b'
o.completeopt = 'menuone,noselect,popup,fuzzy'

-- Tab/S-Tab move through the menu, or jump between snippet fields, or are Tab.
-- Enter accepts only when you've actually picked an item.
vim.keymap.set({ 'i', 's' }, '<Tab>', function()
  if vim.fn.pumvisible() == 1 then return '<C-n>' end
  if vim.snippet.active({ direction = 1 }) then return '<Cmd>lua vim.snippet.jump(1)<CR>' end
  return '<Tab>'
end, { expr = true, desc = 'Next item / snippet field' })

vim.keymap.set({ 'i', 's' }, '<S-Tab>', function()
  if vim.fn.pumvisible() == 1 then return '<C-p>' end
  if vim.snippet.active({ direction = -1 }) then return '<Cmd>lua vim.snippet.jump(-1)<CR>' end
  return '<S-Tab>'
end, { expr = true, desc = 'Prev item / snippet field' })

vim.keymap.set('i', '<CR>', function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ 'selected' }).selected ~= -1 then
    return '<C-y>'
  end
  return '<CR>'
end, { expr = true, desc = 'Accept completion or newline' })

---------------------------------------------------------------------------
-- 6. Diagnostics
---------------------------------------------------------------------------
local sev = vim.diagnostic.severity
vim.diagnostic.config({
  severity_sort = true,
  underline = true,                       -- st has no undercurl; plain underline
  virtual_text = { spacing = 2, source = 'if_many' },
  float = { source = 'if_many' },
  signs = { text = { [sev.ERROR] = 'E', [sev.WARN] = 'W', [sev.INFO] = 'I', [sev.HINT] = 'H' } },
})
-- The default statusline in 0.12 already shows diagnostic counts and LSP progress.

---------------------------------------------------------------------------
-- 7. Syntax trees (built-in treesitter, where a parser exists)
---------------------------------------------------------------------------
-- Neovim ships parsers for C, Lua, Markdown, Vim, vimdoc and query. This turns
-- on tree-based highlighting and folding for any filetype that has a parser
-- plus highlight queries on the runtimepath, so a parser you build and drop
-- into ~/.local/share/nvim/site/parser/ later just starts working.
-- Everything else (C++, Python) uses regex syntax plus the language server's
-- semantic highlighting.
vim.api.nvim_create_autocmd('FileType', {
  group = aug,
  callback = function(ev)
    if vim.treesitter.highlighter.active[ev.buf] then return end
    local lang = vim.treesitter.language.get_lang(ev.match)
    if not lang then return end
    local ok, loaded = pcall(vim.treesitter.language.add, lang)
    if not (ok and loaded) then return end
    local okq, query = pcall(vim.treesitter.query.get, lang, 'highlights')
    if not (okq and query) then return end
    vim.treesitter.start(ev.buf, lang)
    vim.opt_local.foldmethod = 'expr'
    vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end,
})

---------------------------------------------------------------------------
-- 8. Keymaps (IDE-style, all under <Space>)
---------------------------------------------------------------------------
-- Avoided on purpose: Alt+j/k/u/d, Alt+Up/Down, Alt+Home, Shift/Alt+PgUp/PgDn
-- and Ctrl+=/-/0. Your st binds those for scrollback and zoom, so Neovim
-- never sees them.

-- Find
map('n', '<leader>ff', '<Cmd>Pick files<CR>', 'Files')
map('n', '<leader>fg', '<Cmd>Pick grep_live<CR>', 'Grep (live)')
map('n', '<leader>fw', "<Cmd>Pick grep pattern='<cword>'<CR>", 'Grep word under cursor')
map('n', '<leader>fb', '<Cmd>Pick buffers<CR>', 'Buffers')
map('n', '<leader>fo', '<Cmd>Pick oldfiles<CR>', 'Recent files')
map('n', '<leader>fh', '<Cmd>Pick help<CR>', 'Help')
map('n', '<leader>fk', '<Cmd>Pick keymaps<CR>', 'Keymaps')
map('n', '<leader>fr', '<Cmd>Pick resume<CR>', 'Resume last picker')
map('n', '<leader>fd', '<Cmd>Pick diagnostic<CR>', 'Diagnostics')
map('n', '<leader>fs', "<Cmd>Pick lsp scope='document_symbol'<CR>", 'Symbols (file)')
map('n', '<leader>fS', "<Cmd>Pick lsp scope='workspace_symbol'<CR>", 'Symbols (project)')

-- Quick file operations (create/rename/move by editing text, = to apply).
-- The persistent sidebar tree is <leader>e, in plugin/tree.lua.
map('n', '<leader>E', function()
  local path = vim.api.nvim_buf_get_name(0)
  MiniFiles.open(vim.uv.fs_stat(path) and path or nil)
end, 'Edit files around current file')

-- Git
map('n', '<leader>gd', function() MiniDiff.toggle_overlay(0) end, 'Toggle inline diff')
map('n', '<leader>gh', '<Cmd>Pick git_hunks<CR>', 'Changed hunks')
map('n', '<leader>gl', '<Cmd>Git log --oneline<CR>', 'Log')
map('n', '<leader>gb', '<Cmd>vertical Git blame -- %<CR>', 'Blame file')

-- Build, terminal, tools
map('n', '<leader>m', '<Cmd>make<CR>', 'Build (:make, errors to quickfix)')
map('n', '<leader>q', '<Cmd>copen<CR>', 'Open quickfix list')
map('n', '<leader>tu', '<Cmd>Undotree<CR>', 'Undo tree')
map('t', '<Esc><Esc>', [[<C-\><C-n>]], 'Leave terminal mode')

-- Windows and housekeeping
map('n', '<C-h>', '<C-w>h', 'Window left')
map('n', '<C-j>', '<C-w>j', 'Window down')
map('n', '<C-k>', '<C-w>k', 'Window up')
map('n', '<C-l>', '<C-w>l', 'Window right')
map('n', '<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlight')

---------------------------------------------------------------------------
-- 9. Small comforts
---------------------------------------------------------------------------
vim.api.nvim_create_autocmd('TextYankPost', {
  group = aug,
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

vim.api.nvim_create_autocmd('TermOpen', {
  group = aug,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    -- Start typing in the new terminal, unless focus has already moved on
    local win = vim.api.nvim_get_current_win()
    vim.schedule(function()
      if vim.api.nvim_get_current_win() == win then vim.cmd.startinsert() end
    end)
  end,
})
