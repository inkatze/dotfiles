local M = {}

M.setup = function()
  require("lspconfig").yamlls.setup({
    settings = {
      yaml = {
        format = {
          enable = true,
        },
      },
    }
  })
end

return M
