local M = {}

M.setup = function()
  local base = require("inkatze.lspconfig")

  base.setup_server('yamlls', {
    cmd = { 'yaml-language-server', '--stdio' },
    root_dir = function(fname)
      return vim.fs.root(fname, { '.git' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    settings = {
      yaml = {
        format = {
          enable = true,
        },
      },
    }
  }, { 'yaml', 'yaml.docker-compose', 'yaml.gitlab' })
end

return M
