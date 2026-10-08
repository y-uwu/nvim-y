-- ~/.config/nvim/plugin/projects.lua
--
-- Projects and sessions, using only Neovim's built-in :mksession.
--
-- Neovim remembers each project folder. When you quit, the files and splits
-- you had open are saved for the folder you were working in; opening that
-- folder again brings them back. Quick edits (`nvim somefile`, plain `nvim`)
-- don't save or restore anything.
--
--   nvim ~/projects/ws     open a project (restores its last session)
--   <Space>fp              recent projects: pick one to switch to it
--   <Space>o               open any folder as the project
--   :SessionForget         forget the saved session for this project
--
-- Switching saves the project you're leaving first. It refuses while a file
-- has unsaved changes, so nothing is lost. Terminal and agent panels keep
-- running across switches; the tree follows the new project.
--
-- Session files are kept in ~/.local/state/nvim/sessions/, never inside a
-- project, so a cloned repo can't ship a session file that runs code when
-- you open it.

-- What a session saves: open files, splits, tabs, folds and the folder.
-- Not the tree or terminals (they're rebuilt), not split sizes (they're
-- evened out once the tree is back), and not options or keymaps (those come
-- from this config).
vim.o.sessionoptions = 'buffers,curdir,folds,tabpages'

local aug = vim.api.nvim_create_augroup('y_projects', { clear = true })
local dir = vim.fn.stdpath('state') .. '/sessions'

-- True when this Neovim is working on a project (opened on a folder,
-- switched to one, or moved into one with the tree). Only then is the
-- session saved on exit.
local in_project = false

local function normalize(path)
  return (vim.fn.fnamemodify(vim.fn.expand(path), ':p'):gsub('/+$', ''))
end

-- One file per project, named after its path with everything except
-- letters, digits and -._~ percent-encoded (so / can't escape the folder).
local function session_file(path)
  local name = path:gsub('[^%w%-%._~]', function(c) return ('%%%02X'):format(c:byte()) end)
  return dir .. '/' .. name .. '.vim'
end

local function tree_api()
  local ok, api = pcall(require, 'nvim-tree.api')
  return ok and api or nil
end

local function show_tree()
  local tree = tree_api()
  if tree and not tree.tree.is_visible() then
    tree.tree.toggle({ path = vim.fn.getcwd(), focus = false })
  end
end

local function save()
  if not in_project then return end
  vim.fn.mkdir(dir, 'p')
  -- The argument list (the folder you started with) would come back as a
  -- stray buffer, so leave it out.
  vim.cmd('silent! %argdelete')
  vim.cmd('silent mksession! ' .. vim.fn.fnameescape(session_file(vim.fn.getcwd())))
end

local function is_file_buf(b)
  return vim.bo[b].buflisted and vim.bo[b].buftype == ''
end

-- Close the tree and stand in a normal editor window, so a session (or a
-- fresh project) doesn't open files in a window that still carries the
-- tree's or a terminal panel's window settings.
local function prepare_window()
  local tree = tree_api()
  if tree then tree.tree.close() end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_win_get_config(win).relative == '' and vim.bo[b].buftype == '' then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.cmd('topleft vnew')
  local win = vim.api.nvim_get_current_win()
  for name, info in pairs(vim.api.nvim_get_all_options_info()) do
    if info.scope == 'win' then
      local global = vim.api.nvim_get_option_value(name, { scope = 'global' })
      pcall(vim.api.nvim_set_option_value, name, global, { win = win, scope = 'local' })
    end
  end
end

-- Drop leftovers that would show up as tabs: empty unnamed buffers and
-- folder buffers that aren't in any window.
local function cleanup()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if is_file_buf(b) and #vim.fn.win_findbuf(b) == 0 and not vim.bo[b].modified then
      local name = vim.api.nvim_buf_get_name(b)
      local empty = name == '' and vim.api.nvim_buf_line_count(b) == 1
        and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == ''
      if empty or (name ~= '' and vim.fn.isdirectory(name) == 1) then
        pcall(vim.api.nvim_buf_delete, b, {})
      end
    end
  end
end

---------------------------------------------------------------------------
-- Switching projects
---------------------------------------------------------------------------
local function switch(path)
  path = normalize(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.notify('Not a folder: ' .. path, vim.log.levels.WARN)
    return
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if is_file_buf(b) and vim.bo[b].modified then
      vim.notify('Save or undo your changes first (:wa saves all).', vim.log.levels.WARN)
      return
    end
  end

  save()

  -- Down to one empty editor window: panels are hidden (still running),
  -- the old project's files are closed.
  prepare_window()
  vim.cmd('silent! tabonly | silent! only | enew')
  local keep = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= keep and is_file_buf(b) then pcall(vim.api.nvim_buf_delete, b, {}) end
  end

  vim.cmd.cd(vim.fn.fnameescape(path))
  in_project = true
  local file = session_file(path)
  if vim.fn.filereadable(file) == 1 then
    vim.cmd('silent! source ' .. vim.fn.fnameescape(file))
  else
    show_tree()
  end
end

vim.keymap.set('n', '<leader>o', function()
  vim.ui.input({ prompt = 'Open folder: ', default = vim.fn.getcwd() .. '/', completion = 'dir' },
    function(input)
      if input and input ~= '' then switch(input) end
    end)
end, { desc = 'Open folder (switch project)' })

vim.keymap.set('n', '<leader>fp', function()
  local items = {}
  for name, kind in vim.fs.dir(dir) do
    if kind == 'file' and name:sub(-4) == '.vim' then
      local path = vim.uri_decode(name:sub(1, -5))
      local stat = vim.uv.fs_stat(dir .. '/' .. name)
      if vim.fn.isdirectory(path) == 1 and stat then
        table.insert(items, { path = path, time = stat.mtime.sec })
      end
    end
  end
  if #items == 0 then
    vim.notify('No saved projects yet. Open a folder with `nvim <folder>` or <Space>o.')
    return
  end
  table.sort(items, function(a, b) return a.time > b.time end)
  local home = vim.env.HOME or ''
  local labels, by_label = {}, {}
  for _, it in ipairs(items) do
    local label = it.path:sub(1, #home) == home and '~' .. it.path:sub(#home + 1) or it.path
    table.insert(labels, label)
    by_label[label] = it.path
  end
  local function pick(label)
    if label then vim.schedule(function() switch(by_label[label]) end) end
  end
  if _G.MiniPick then
    MiniPick.start({ source = { name = 'Recent projects', items = labels, choose = pick } })
  else
    vim.ui.select(labels, { prompt = 'Recent projects' }, pick)
  end
end, { desc = 'Recent projects' })

vim.api.nvim_create_user_command('SessionForget', function()
  local file = session_file(vim.fn.getcwd())
  os.remove(file)
  in_project = false
  vim.notify('Forgot the session for ' .. vim.fn.getcwd() .. ' (it will not be saved on exit).')
end, { desc = 'Delete the saved session for the current project' })

---------------------------------------------------------------------------
-- Automatic save and restore
---------------------------------------------------------------------------
-- `nvim somefolder`: restore that folder's session. Scheduled so it runs
-- after the tree's own startup handling. A :restart (ZR) restores its own
-- session, so this steps aside then.
vim.api.nvim_create_autocmd('VimEnter', {
  group = aug,
  callback = function()
    local args = vim.v.argf
    if #args ~= 1 or vim.fn.isdirectory(args[1]) == 0 then return end
    in_project = true
    if vim.v.startreason ~= 'normal' then return end
    local file = session_file(normalize(args[1]))
    if vim.fn.filereadable(file) == 0 then return end
    vim.schedule(function()
      prepare_window()
      vim.cmd('silent! source ' .. vim.fn.fnameescape(file))
    end)
  end,
})

-- After any session loads (yours or ZR's), tidy up, put the tree back and
-- even out the splits beside it.
vim.api.nvim_create_autocmd('SessionLoadPost', {
  group = aug,
  callback = function()
    in_project = true
    vim.schedule(function()
      cleanup()
      show_tree()
      vim.cmd('wincmd =')
    end)
  end,
})

-- Moving into a folder with the tree (<C-]>, -) also makes it the project.
vim.api.nvim_create_autocmd('DirChanged', {
  group = aug,
  pattern = 'global',
  callback = function()
    if vim.v.vim_did_enter == 1 then in_project = true end
  end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = aug,
  callback = save,
})
