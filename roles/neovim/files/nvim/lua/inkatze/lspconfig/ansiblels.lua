local M = {}

M.setup = function()
  local base = require("inkatze.lspconfig")

  base.setup_server('ansiblels', {
    cmd = { 'ansible-language-server', '--stdio' },
    root_dir = function(fname)
      return vim.fs.root(fname, { 'ansible.cfg', '.ansible-lint' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    settings = {
      ansible = {
        ansible = {
          path = "ansible"
        },
        executionEnvironment = {
          enabled = false
        },
        python = {
          interpreterPath = "python"
        },
        validation = {
          enabled = true,
          lint = {
            enabled = true,
            path = "ansible-lint"
          }
        }
      }
    }
  }, { 'yaml.ansible' })
end

return M
