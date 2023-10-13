return {
  -- neovim's lsp pre-configurations
  "neovim/nvim-lspconfig",
  dependencies = {
    "folke/which-key.nvim",
    { "onsails/lspkind.nvim", lazy = true },
  },
  build = "brew install lua-language-server efm-langserver",
  event = "BufAdd",
  config = function()
    require("inkatze.lspconfig.lua").setup()
    require("inkatze.lspconfig.misc").setup()
    require("inkatze.lspconfig.ruby").setup()

    local wk = require("which-key")
    wk.register({
      ld = {
        name = "LSP diagnostics",
        o = { vim.diagnostic.open_float, "Opens float window with diagnostic information" },
        p = { vim.diagnostic.goto_prev, "Jump to pevious diagnostic" },
        n = { vim.diagnostic.goto_next, "Jump to next diagnostic" },
        l = { vim.diagnostic.setloclist, "Set loc list" },
      },
    }, { prefix = "<leader>", silent = true, nnoremap = true })

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
