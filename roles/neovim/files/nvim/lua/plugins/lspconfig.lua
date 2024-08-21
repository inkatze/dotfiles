return {
  -- neovim's lsp pre-configurations
  "neovim/nvim-lspconfig",
  dependencies = {
    "folke/which-key.nvim",
    { "onsails/lspkind.nvim", lazy = true },
  },
  build =
  "brew install lua-language-server efm-langserver",
  event = "BufRead",
  config = function()
    require("inkatze.lspconfig.ansiblels").setup()
    require("inkatze.lspconfig.gradle").setup()
    require("inkatze.lspconfig.lua").setup()
    require("inkatze.lspconfig.misc").setup()
    require("inkatze.lspconfig.ruby").setup()
    require("inkatze.lspconfig.yamlls").setup()

    local wk = require("which-key")
    wk.add({
      { "<leader>ld",  group = "LSP diagnostics" },
      { "<leader>ldl", vim.diagnostic.setloclist, desc = "Set loc list" },
      { "<leader>ldn", vim.diagnostic.goto_next,  desc = "Jump to next diagnostic" },
      { "<leader>ldo", vim.diagnostic.open_float, desc = "Opens float window with diagnostic information" },
      { "<leader>ldp", vim.diagnostic.goto_prev,  desc = "Jump to pevious diagnostic" },
    })

    require("lspkind").init({
      -- defines how annotations are shown
      -- default: symbol
      -- options: 'text', 'text_symbol', 'symbol_text', 'symbol'
      mode = "symbol_text",
      -- default symbol map
      -- can be either 'default' (requires nerd-fonts font) or
      -- 'codicons' for codicon preset (requires vscode-codicons font)
      --
      -- default: 'default'
      preset = "codicons",
      -- override preset symbols
      --
      -- default: {}
      symbol_map = {
        Text = "󰊄",
        Method = "",
        Function = "󰊕",
        Constructor = "",
        Field = "",
        Variable = "",
        Class = "",
        Interface = "",
        Module = "󰕳",
        Property = "",
        Unit = "",
        Value = "",
        Enum = "",
        Keyword = "",
        Snippet = "",
        Color = "",
        File = "",
        Reference = "",
        Folder = "",
        EnumMember = "",
        Constant = "",
        Struct = "",
        Event = "",
        Operator = "",
        TypeParameter = "",
      },
    })
  end,
}
