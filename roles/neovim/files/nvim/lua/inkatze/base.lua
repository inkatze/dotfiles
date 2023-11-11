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
vim.opt.pumblend = 5 -- pseudo-transparency for pop-up menu

-- Highlight
vim.opt.cursorline = true
vim.opt.termguicolors = true

vim.g.mapleader = ","

-- Makes invisible chars visible
vim.opt.list = true
vim.opt.listchars:append("space:⋅")

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
