local M = {}

M.setup = function()
  require("lspconfig").ruby_lsp.setup({
    on_attach = require("inkatze.lspconfig").on_attach,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  })

  require("lspconfig").sorbet.setup({
    cmd = { "bundle", "exec", "srb", "tc", "--lsp" },
    on_attach = require("inkatze.lspconfig").on_attach,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  })

  require("lspconfig").rubocop.setup({
    cmd = { "bundle", "exec", "rubocop", "--lsp" },
    on_attach = require("inkatze.lspconfig").on_attach,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  })
end

return M
