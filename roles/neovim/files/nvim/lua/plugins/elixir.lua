return {
  "elixir-tools/elixir-tools.nvim",
  ft = { "elixir", "eelixir", "heex", "surface" },
  version = "*",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local elixir = require("elixir")
    local elixirls = require("elixir.elixirls")

    elixir.setup({
      nextls = {
        enable = true, -- defaults to false
        on_attach = require("inkatze.lspconfig").on_attach,
      },
      credo = {
        enable = true, -- defaults to true
        on_attach = require("inkatze.lspconfig").on_attach,
      },
      elixirls = {
        enable = true,
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
