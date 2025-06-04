vim.opt_local.autoindent = true
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2

local dap = require('dap')
local host = '127.0.0.1'
local port = 4711

dap.adapters.ruby = {
  type = 'server',
  host = host,
  port = port,
}

dap.configurations.ruby = {
  {
    type = 'ruby',
    request = 'attach',
    name = 'Attach to TruffleRuby',
    remote_host = host,
    remote_port = port,
    stopOnEntry = false,
  },
}
