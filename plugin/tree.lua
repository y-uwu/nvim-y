-- ~/.config/nvim/plugin/tree.lua
--
-- Project file tree in a left sidebar, using nvim-tree.lua (no required
-- dependencies). Plain ASCII: folders end in /, > is closed, v is open.
--
-- Opening a project:
--   nvim ~/some/project     from the shell: tree on the left, empty editor
--   <Space>o                from inside Neovim: switch to another folder
--   <Space>e                show the tree, jump to it, or hide it
--
-- Mouse: one click on a folder opens/closes it, one click on a file opens it
-- in the editor you used last. Double-clicking does the same thing.
--
-- Keys inside the tree (press g? for the full list):
--   <CR> open    <C-v> open in a split to the right    <C-x> split below
--   a new file/folder (end with / for a folder)    r rename    d delete
--   c copy  x cut  p paste    H show dotfiles    I show git-ignored files
--   <C-]> make the folder under the cursor the project    - go up a level

vim.pack.add({
  { src = 'https://github.com/nvim-tree/nvim-tree.lua', version = vim.version.range('1') },
})

local aug = vim.api.nvim_create_augroup('y_tree', { clear = true })

---------------------------------------------------------------------------
-- Which window a file opens in
---------------------------------------------------------------------------
-- Opens files in the editor window you were in last, like an IDE. The
-- default asks you to pick a window by letter when you have splits.
local function is_editor(win)
  if not vim.api.nvim_win_is_valid(win) then return false end
  if vim.api.nvim_win_get_config(win).relative ~= '' then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == '' and vim.bo[buf].filetype ~= 'NvimTree'
end

local last_editor = nil
vim.api.nvim_create_autocmd('WinEnter', {
  group = aug,
  callback = function()
    local win = vim.api.nvim_get_current_win()
    if is_editor(win) then last_editor = win end
  end,
})

local function pick_window()
  if last_editor and is_editor(last_editor) then return last_editor end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(win) then return win end
  end
  -- No editor window left (only tree and panels): make one beside the tree.
  local tree_win = require('nvim-tree.api').tree.winid()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = 'wipe'
  return vim.api.nvim_open_win(scratch, false, { split = 'right', win = tree_win or 0 })
end

---------------------------------------------------------------------------
-- Mouse and keys inside the tree
---------------------------------------------------------------------------
local function on_attach(buf)
  local api = require('nvim-tree.api')
  api.map.on_attach.default(buf)

  local function opts(desc)
    return { desc = 'tree: ' .. desc, buffer = buf, nowait = true }
  end

  -- One click opens. The second click of a double-click is ignored, so a
  -- double-click doesn't close the folder it just opened. Clicking the
  -- project name on the top line does nothing.
  vim.keymap.set('n', '<LeftRelease>', function()
    local node = api.tree.get_node_under_cursor()
    if node and node.parent then api.node.open.edit() end
  end, opts('Open with mouse'))
  vim.keymap.set('n', '<2-LeftMouse>', '<Nop>', opts('Ignore second click'))
  vim.keymap.set('n', '<2-LeftRelease>', '<Nop>', opts('Ignore second click'))

  -- (Double-clicking a file is handled by the global mappings further down.)

  -- The default <C-k> (file info) would shadow window movement; move it to i.
  vim.keymap.del('n', '<C-k>', { buffer = buf })
  vim.keymap.set('n', 'i', api.node.show_info_popup, opts('Info'))
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
require('nvim-tree').setup({
  on_attach = on_attach,
  hijack_cursor = true,              -- keep the cursor on the file name
  sync_root_with_cwd = true,         -- tree root follows :cd
  update_focused_file = { enable = true },  -- highlight the file you're editing
  view = { width = 32, preserve_window_proportions = true },
  actions = {
    open_file = { window_picker = { picker = pick_window } },
    -- <C-]> on a folder (or - to go up) makes it the project for everything:
    -- file finder, grep and new terminals, not just the tree window.
    change_dir = { global = true },
  },
  renderer = {
    root_folder_label = function(path) return vim.fn.fnamemodify(path, ':t') .. '/' end,
    add_trailing = true,             -- folders end in /
    group_empty = true,              -- show a/b/c/ on one line when folders hold one folder
    highlight_opened_files = 'name', -- files open in the editor stand out
    icons = {
      symlink_arrow = ' -> ',
      show = { file = false, folder = false },
      glyphs = {
        modified = '*',
        hidden = 'h',
        bookmark = 'm',
        folder = { arrow_closed = '>', arrow_open = 'v' },
        git = {
          unstaged = 'M', staged = 'S', unmerged = 'U', renamed = 'R',
          untracked = '?', deleted = 'D', ignored = '!',
        },
      },
    },
  },
  diagnostics = {
    enable = true,
    show_on_dirs = true,
    icons = { hint = 'H', info = 'I', warning = 'W', error = 'E' },
  },
  modified = { enable = true },      -- mark files with unsaved changes
})

---------------------------------------------------------------------------
-- `nvim somefolder` from the shell
---------------------------------------------------------------------------
-- Makes that folder the project (:cd), shows the tree as a sidebar, and
-- leaves an empty editor beside it, instead of a full-screen tree.
vim.api.nvim_create_autocmd('VimEnter', {
  group = aug,
  callback = function()
    -- v:argf (0.12) is the startup arguments as typed; argv() has already
    -- been renamed by the tree by this point.
    local args = vim.v.argf
    if #args ~= 1 then return end
    local dir = vim.fn.fnamemodify(args[1], ':p')
    if vim.fn.isdirectory(dir) == 0 then return end
    local api = require('nvim-tree.api')
    vim.cmd.cd(vim.fn.fnameescape(dir))
    api.tree.close()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= '' and vim.fn.isdirectory(name) == 1 then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      end
    end
    vim.cmd.enew()
    last_editor = vim.api.nvim_get_current_win()
    api.tree.open({ path = dir })
  end,
})

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------
-- Double-clicking a file: the first click opens it and moves you to the
-- editor, so the second click would land back on the tree and start a text
-- selection. Drop that second click and its release; double-clicks anywhere
-- else work as usual.
local drop_release = false
vim.keymap.set('n', '<2-LeftMouse>', function()
  local win = vim.fn.getmousepos().winid
  if win ~= 0 and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'NvimTree' then
    drop_release = true
    return ''
  end
  return '<2-LeftMouse>'
end, { expr = true, desc = 'Double-click (ignored on the tree)' })
vim.keymap.set('n', '<2-LeftRelease>', function()
  if drop_release then
    drop_release = false
    return ''
  end
  return '<2-LeftRelease>'
end, { expr = true, desc = 'Double-click release' })

vim.keymap.set('n', '<leader>e', function()
  local api = require('nvim-tree.api')
  if api.tree.is_visible() and not api.tree.is_tree_buf(0) then
    api.tree.focus()
  else
    api.tree.toggle({ find_file = true })
  end
end, { desc = 'File tree (open / jump / hide)' })

-- Switch projects: type or Tab-complete a folder path, Enter to open it.
-- The file finder (<Space>ff) and grep (<Space>fg) then search that folder.
vim.keymap.set('n', '<leader>o', function()
  vim.ui.input({ prompt = 'Open folder: ', default = vim.fn.getcwd() .. '/', completion = 'dir' },
    function(input)
      if not input or input == '' then return end
      local dir = vim.fn.fnamemodify(vim.fn.expand(input), ':p')
      if vim.fn.isdirectory(dir) == 0 then
        vim.notify('Not a folder: ' .. dir, vim.log.levels.WARN)
        return
      end
      vim.cmd.cd(vim.fn.fnameescape(dir))
      require('nvim-tree.api').tree.open({ path = dir })
    end)
end, { desc = 'Open folder (switch project)' })
