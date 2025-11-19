return {
  "nvimdev/lspsaga.nvim",
  event = "LspAttach",
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
    "folke/which-key.nvim"
  },
  config = function()
    require("lspsaga").setup({
      ui = {
        kind = require("catppuccin.groups.integrations.lsp_saga").custom_kind(),
      },
      symbol_in_winbar = {
        enable = false
      },
      lightbulb = {
        enable = true,
        sign = true,
        virtual_text = false,
      },
    })

    local wk = require("which-key")

    wk.add({
      { "<A-d>", "<cmd>Lspsaga term_toggle<CR>",                                                                       desc = "Float terminal" },
      { "K",     "<cmd>Lspsaga hover_doc<CR>",                                                                         desc = "Hover doc" },
      { "[E",    function() require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, desc = "Jump to previous error" },
      { "[e",    "<cmd>Lspsaga diagnostic_jump_prev<CR>",                                                              desc = "Jump to previous diagnostic" },
      { "]E",    function() require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR }) end, desc = "Jump to next error" },
      { "]e",    "<cmd>Lspsaga diagnostic_jump_next<CR>",                                                              desc = "Jump to next diagnostic" },
      { "gd",    "<cmd>Lspsaga goto_definition<CR>",                                                                   desc = "Go to the definition under the cursor" },
      { "gp",    "<cmd>Lspsaga peek_definition<CR>",                                                                   desc = "Peek Definition" },
      { "gr",    "<cmd>Lspsaga rename<CR>",                                                                            desc = "lspsaga rename" },
    })

    wk.add({
      { "<leader>",    group = "lspsaga commands" },
      { "<leader>ccd", "<cmd>Lspsaga show_cursor_diagnostics<CR>", desc = "Show cursor diagnostics" },
      { "<leader>cd",  "<cmd>Lspsaga show_line_diagnostics<CR>",   desc = "Show line diagnostics" },
      { "<leader>o",   "<cmd>Lspsaga outline<CR>",                 desc = "Objects outline" },
      { "<leader>sf",  "<cmd>Lspsaga finder<CR>",                  desc = "Shows a list of references and implementations" },
      { "<leader>ca",  "<cmd>Lspsaga code_action<CR>",             desc = "Code action",                                   mode = { "n", "v" } },
    })
  end,
}
