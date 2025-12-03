-- Layout
vim.wo.number = true -- show line number

-- Indentation
vim.opt.smartindent = true

-- Search
vim.opt.hlsearch = true   -- Highlight search
vim.opt.ignorecase = true -- Case insensitive
vim.opt.incsearch = true  -- Search as you type
vim.opt.infercase = true
vim.opt.smartcase = true

-- Editor
vim.opt.backup = false
vim.opt.expandtab = true
vim.opt.shell = "fish"
vim.opt.pumblend = 5       -- pseudo-transparency for pop-up menu
vim.opt.signcolumn = "yes" -- leaves enough space in the signcolumn for lspsaga's lightbulb

-- Highlight
vim.opt.cursorline = true
vim.opt.termguicolors = true

vim.g.mapleader = ","
vim.g.loaded_perl_provider = 0

-- Clipboard: Use OSC 52 for remote SSH sessions
-- This allows copying to your local clipboard when SSH'd into a remote machine
-- Note: OSC 52 only supports copy (not paste), so paste uses default terminal behavior
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = function()
      return { vim.fn.getreg(''), vim.fn.getregtype('') }
    end,
    ['*'] = function()
      return { vim.fn.getreg(''), vim.fn.getregtype('') }
    end,
  },
}

-- Makes invisible chars visible
vim.opt.list = true
vim.opt.listchars:append("space:⋅,trail:󱁐,tab:⋅")

vim.api.nvim_create_user_command("CpPathClipboard", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify('Copied "' .. path .. '" to the clipboard!')
end, {})

vim.api.nvim_create_user_command("CpPath", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("", path)
  vim.notify('Copied "' .. path .. '" to the register!')
end, {})
