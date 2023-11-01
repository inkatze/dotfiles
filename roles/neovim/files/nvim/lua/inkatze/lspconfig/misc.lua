local M = {}

local servers = {
  "angularls",
  "bashls",
  "graphql",
  "jsonls",
  "pyright",
  "stylelint_lsp",
  "tailwindcss",
  "tsserver",
  "vimls",
  "yamlls"
}

M.setup = function()
  for _, server in ipairs(servers)
  do
    require("lspconfig")[server].setup({
      on_attach = require("inkatze.lspconfig").on_attach,
      capabilities = require("cmp_nvim_lsp").default_capabilities(),
    })
  end
end

return M
