return {
  "elixir-tools/elixir-tools.nvim",
  event = { "BufReadPre", "BufNewFile" },
  version = "*",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local elixir = require("elixir")
    local elixirls = require("elixir.elixirls")

    elixir.setup({
      nextls = {
        enable = true,
        on_attach = require("inkatze.lspconfig").on_attach,
      },
      credo = {
        enable = false,
        on_attach = require("inkatze.lspconfig").on_attach,
      },
      elixirls = {
        enable = true,
        format = { enabled = true },
        settings = elixirls.settings({
          dialyzerEnabled = true,
          fetchDeps = true,
          enableTestLenses = true,
          suggestSpecs = true,
        }),
        on_attach = require("inkatze.lspconfig").on_attach,
      },
    })
  end,
}
