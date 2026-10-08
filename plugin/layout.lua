-- ~/.config/nvim/plugin/layout.lua
--
-- The IDE layout pieces, with no extra plugins:
--   1. open files as clickable tabs across the top
--   2. keys for putting files side by side
--   3. a terminal panel along the bottom and an agent panel down the right
--   4. one key that hides every panel (tree included) and brings them back
--
-- Panels keep running while hidden. Hiding a panel only closes its window;
-- the terminal buffer and its process stay alive, so showing it again gives
-- you the same shell or agent session.
--
-- Panel keys open a panel, jump to it if it's open elsewhere, or hide it if
-- you're already in it:
--   <Space>tt terminal    <Space>a agent    <Space>e tree (plugin/tree.lua)
--   <Space>z hide all panels / bring them back
-- Inside a panel: Ctrl-\ Ctrl-n gets you to normal mode (Esc Esc also works
-- in the terminal panel), or just click another window.

-- Command the agent panel runs. Any terminal-based coding agent works.
local agent_cmd = { 'claude' }

local aug = vim.api.nvim_create_augroup('y_layout', { clear = true })
local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

---------------------------------------------------------------------------
-- 1. Open files as tabs
---------------------------------------------------------------------------
-- Click a tab to switch to it, middle-click to close it. [b and ]b (built
-- in) step through them.
--
-- Closing a file never closes Neovim, a split, the tree or a panel: the
-- window stays and shows your previous file, or an empty editor if that was
-- the last one. :q is still "quit" as in vim.
require('mini.tabline').setup({
  show_icons = false,
  -- An empty editor shows as [No Name] (mini's default is *, which looks
  -- like an unsaved-changes marker).
  format = function(_, label)
    if label:sub(1, 1) == '*' then label = '[No Name]' end
    return ' ' .. label .. ' '
  end,
})
require('mini.bufremove').setup()

-- Opening a file clears away empty [No Name] editors left behind by closing
-- the last file (only empty ones that aren't on screen anywhere).
vim.api.nvim_create_autocmd('BufEnter', {
  group = aug,
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= '' or vim.api.nvim_buf_get_name(ev.buf) == '' then return end
    vim.schedule(function()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buflisted and vim.bo[b].buftype == '' and not vim.bo[b].modified
          and vim.api.nvim_buf_get_name(b) == '' and #vim.fn.win_findbuf(b) == 0
          and vim.api.nvim_buf_line_count(b) == 1
          and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == '' then
          pcall(vim.api.nvim_buf_delete, b, {})
        end
      end
    end)
  end,
})

local function is_editor(win)
  return vim.api.nvim_win_get_config(win).relative == ''
    and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ''
end

-- The editor window to act on: this one, or (from the tree or a panel) the
-- editor you were in last.
local function editor_window()
  local cur = vim.api.nvim_get_current_win()
  if is_editor(cur) then return cur end
  local prev = vim.fn.win_getid(vim.fn.winnr('#'))
  if prev ~= 0 and is_editor(prev) then return prev end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(win) then return win end
  end
end

local function close_file(buf)
  if not buf then
    local win = editor_window()
    if not win then return end
    buf = vim.api.nvim_win_get_buf(win)
  end
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return end
  if vim.bo[buf].modified then
    local name = vim.api.nvim_buf_get_name(buf)
    if name == '' then
      if vim.fn.confirm('Close this new file without saving it?', '&Discard\n&Cancel', 2) ~= 1 then
        return
      end
    else
      local choice = vim.fn.confirm('Save changes to ' .. vim.fn.fnamemodify(name, ':.') .. '?',
        '&Save\n&Discard\n&Cancel', 1)
      if choice == 1 then
        local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('write') end)
        if not ok then
          vim.notify(err, vim.log.levels.ERROR)
          return
        end
      elseif choice ~= 2 then
        return
      end
    end
  end
  MiniBufremove.delete(buf, true)
end

-- Clicking a tab shows that file in the editor, even if you're in the tree
-- or a panel (instead of replacing the tree or terminal with it).
local function show_file(buf)
  local win = editor_window()
  if not win then return end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, buf)
end

_G.YLayout = { close_file = close_file, show_file = show_file }
vim.cmd([[
  function! MiniTablineSwitchBuffer(buf_id, clicks, button, mod)
    if a:button ==# 'm'
      call v:lua.YLayout.close_file(a:buf_id)
    else
      call v:lua.YLayout.show_file(a:buf_id)
    endif
  endfunction
]])

map('n', '<leader>bd', function() close_file() end, 'Close file')
map('n', '<leader>bo', function()
  local win = editor_window()
  local keep = win and vim.api.nvim_win_get_buf(win)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and b ~= keep then close_file(b) end
  end
end, 'Close other files')

---------------------------------------------------------------------------
-- 2. Files side by side
---------------------------------------------------------------------------
-- Drag a split border with the mouse to resize it.
map('n', '<leader>wv', '<Cmd>vsplit<CR>', 'Split right')
map('n', '<leader>ws', '<Cmd>split<CR>', 'Split below')
map('n', '<leader>wc', function()
  local editors = vim.tbl_filter(is_editor, vim.api.nvim_tabpage_list_wins(0))
  if is_editor(vim.api.nvim_get_current_win()) and #editors == 1 then
    close_file()                     -- the last split keeps its place, just empties
  else
    vim.cmd('close')
  end
end, 'Close this split')
map('n', '<leader>w=', '<C-w>=', 'Even out split sizes')

---------------------------------------------------------------------------
-- 3. Terminal and agent panels
---------------------------------------------------------------------------
local panels = {
  term  = { label = ' Terminal', size = 15 },
  agent = { label = ' Agent', size = 80, cmd = agent_cmd },
}

local function tree_api()
  local ok, api = pcall(require, 'nvim-tree.api')
  return ok and api or nil
end

local function is_open(p)
  return p.win ~= nil and vim.api.nvim_win_is_valid(p.win)
end

local function is_running(p)
  return p.buf ~= nil and vim.api.nvim_buf_is_valid(p.buf) and p.chan ~= nil
    and vim.fn.jobwait({ p.chan }, 0)[1] == -1
end

-- Enter terminal mode in `win`, but only if it's still the current window
-- and still shows a terminal once Neovim gets there. (A split made from a
-- panel briefly shows the panel's buffer; this keeps that new window out of
-- insert mode.)
local function insert_in(win)
  vim.schedule(function()
    if vim.api.nvim_get_current_win() == win
      and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'terminal'
      and vim.api.nvim_get_mode().mode:sub(1, 1) == 'n' then
      vim.cmd.startinsert()
    end
  end)
end

local function hide(name)
  local p = panels[name]
  if is_open(p) then pcall(vim.api.nvim_win_close, p.win, false) end
  p.win = nil
end

-- Put the panel's terminal into its window, starting the process if needed.
local function attach(name)
  local p = panels[name]
  if is_running(p) then
    vim.api.nvim_win_set_buf(p.win, p.buf)
  else
    local old = p.buf
    p.buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_win_set_buf(p.win, p.buf)
    if old and vim.api.nvim_buf_is_valid(old) then
      vim.api.nvim_buf_delete(old, { force = true })
    end
    p.chan = vim.fn.jobstart(p.cmd or { vim.o.shell }, { term = true })
    vim.bo[p.buf].bufhidden = 'hide'
    vim.b[p.buf].y_panel = name
    if name == 'agent' then
      -- Send a single Esc straight to the agent (it uses Esc to interrupt)
      -- instead of waiting to see if it's the start of Esc Esc.
      vim.keymap.set('t', '<Esc>', '<Esc>', { buffer = p.buf, nowait = true })
    end
  end
  -- Set these on the panel window only (like :setlocal), so your defaults
  -- for other windows stay untouched.
  local function setlocal(opt, value)
    vim.api.nvim_set_option_value(opt, value, { win = p.win, scope = 'local' })
  end
  setlocal('winfixheight', name == 'term')
  setlocal('winfixwidth', name == 'agent')
  setlocal('number', false)
  setlocal('relativenumber', false)
  setlocal('signcolumn', 'no')
  setlocal('winbar', p.label)
end

local function show(name, focus)
  local p = panels[name]
  if p.cmd and vim.fn.executable(p.cmd[1]) ~= 1 then
    vim.notify(("Agent panel: '%s' isn't installed. Set agent_cmd at the top of plugin/layout.lua.")
      :format(p.cmd[1]), vim.log.levels.WARN)
    return
  end
  local prev = vim.api.nvim_get_current_win()

  if name == 'term' then
    -- A bottom split spans the whole screen width, so it would also run
    -- under the tree and the agent. Close those first and reopen them after,
    -- which leaves the terminal under the editor only, like VS Code.
    local tree = tree_api()
    local had_tree = tree and tree.tree.is_visible()
    local had_agent = is_open(panels.agent)
    if had_tree then tree.tree.close() end
    if had_agent then hide('agent') end
    vim.cmd('botright ' .. p.size .. 'split')
    p.win = vim.api.nvim_get_current_win()
    attach(name)
    if had_tree then tree.tree.toggle({ focus = false }) end
    if had_agent then show('agent', false) end
  else
    vim.cmd('botright vertical ' .. p.size .. 'split')
    p.win = vim.api.nvim_get_current_win()
    attach(name)
  end

  if focus then
    vim.api.nvim_set_current_win(p.win)
    insert_in(p.win)
  elseif vim.api.nvim_win_is_valid(prev) then
    vim.api.nvim_set_current_win(prev)
  end
end

local function toggle(name)
  local p = panels[name]
  if not is_open(p) then
    show(name, true)
  elseif vim.api.nvim_get_current_win() ~= p.win then
    vim.api.nvim_set_current_win(p.win)
    insert_in(p.win)
  else
    hide(name)
  end
end

map('n', '<leader>tt', function() toggle('term') end, 'Terminal panel')
map('n', '<leader>a', function() toggle('agent') end, 'Agent panel')

-- Clicking into a panel puts you straight into terminal mode.
vim.api.nvim_create_autocmd('WinEnter', {
  group = aug,
  callback = function()
    if vim.b.y_panel then insert_in(vim.api.nvim_get_current_win()) end
  end,
})

-- Typing `exit` in a panel hides it; the next toggle starts a fresh one.
vim.api.nvim_create_autocmd('TermClose', {
  group = aug,
  callback = function(ev)
    local name = vim.b[ev.buf].y_panel
    if name and vim.v.event.status == 0 then vim.schedule(function() hide(name) end) end
  end,
})

---------------------------------------------------------------------------
-- 4. Hide / restore everything
---------------------------------------------------------------------------
local stashed = nil

map('n', '<leader>z', function()
  local tree = tree_api()
  if stashed then
    local cur = vim.api.nvim_get_current_win()
    if stashed.term then show('term', false) end
    if stashed.tree and tree then tree.tree.toggle({ focus = false }) end
    if stashed.agent then show('agent', false) end
    if vim.api.nvim_win_is_valid(cur) then vim.api.nvim_set_current_win(cur) end
    stashed = nil
    return
  end
  local s = {
    tree = tree ~= nil and tree.tree.is_visible(),
    term = is_open(panels.term),
    agent = is_open(panels.agent),
  }
  if not (s.tree or s.term or s.agent) then return end
  if s.tree then tree.tree.close() end
  hide('term')
  hide('agent')
  stashed = s
end, 'Hide / restore all panels')

-- When you :q the last editor window, close the panels too so Neovim exits
-- instead of leaving you alone with the tree or a terminal. Quitting ends the
-- panel processes (shell and agent session), same as closing an IDE window;
-- use <Space>z when you only want them out of the way.
vim.api.nvim_create_autocmd('QuitPre', {
  group = aug,
  callback = function()
    local tree = tree_api()
    local function is_panel(win)
      local buf = vim.api.nvim_win_get_buf(win)
      return vim.b[buf].y_panel ~= nil or (tree ~= nil and tree.tree.is_tree_buf(buf))
    end
    local cur = vim.api.nvim_get_current_win()
    if is_panel(cur) then return end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if win ~= cur and vim.api.nvim_win_get_config(win).relative == '' and not is_panel(win) then
        return
      end
    end
    if tree then tree.tree.close() end
    hide('term')
    hide('agent')
  end,
})
