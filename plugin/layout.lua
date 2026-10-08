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
-- Click a tab to switch to it. [b and ]b (built in) step through them.
require('mini.tabline').setup({ show_icons = false })
require('mini.bufremove').setup()

map('n', '<leader>bd', function() MiniBufremove.delete() end, 'Close file (keep window)')
map('n', '<leader>bo', function()
  local cur = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and b ~= cur then MiniBufremove.delete(b) end
  end
end, 'Close other files')

---------------------------------------------------------------------------
-- 2. Files side by side
---------------------------------------------------------------------------
-- Drag a split border with the mouse to resize it.
map('n', '<leader>wv', '<Cmd>vsplit<CR>', 'Split right')
map('n', '<leader>ws', '<Cmd>split<CR>', 'Split below')
map('n', '<leader>wc', '<Cmd>close<CR>', 'Close this split')
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
-- once Neovim gets there (avoids starting insert in the wrong window).
local function insert_in(win)
  vim.schedule(function()
    if vim.api.nvim_get_current_win() == win and vim.api.nvim_get_mode().mode:sub(1, 1) == 'n' then
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
  local wo = vim.wo[p.win]
  wo.winfixheight = name == 'term'
  wo.winfixwidth = name == 'agent'
  wo.number, wo.relativenumber, wo.signcolumn = false, false, 'no'
  wo.winbar = p.label
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
