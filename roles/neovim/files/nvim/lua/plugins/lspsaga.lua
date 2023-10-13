return {
  "nvimdev/lspsaga.nvim",
  after = "nvim-lspconfig",
  event = "BufRead",
  dependencies = { "folke/which-key.nvim" },
  config = function()
    local saga = require("lspsaga")

    saga.setup({
      ui = {
        kind = require("catppuccin.groups.integrations.lsp_saga").custom_kind(),
      },
      symbol_in_winbar = { enable = false },
    })

    local jump_to_prev_error = function()
      require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
    end

    local jump_to_next_error = function()
      require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
    end

    local wk = require("which-key")

    wk.register({
      -- use <C-t> to jump back
      name = "lspsaga commands",
      gd = {
        "<cmd>Lspsaga goto_definition<CR>",
        "Go to the definition under the cursor",
        silent = true,
      },
      gr = { "<cmd>Lspsaga rename<CR>", "lspsaga rename", silent = true },
      gp = { "<cmd>Lspsaga peek_definition<CR>", "Peek Definition", silent = true },
      K = { "<cmd>Lspsaga hover_doc<CR>", "Hover doc", silent = true },
      ["<A-d>"] = { "<cmd>Lspsaga term_toggle<CR>", "Float terminal", silent = true },
      ["[e"] = { "<cmd>Lspsaga diagnostic_jump_prev<CR>", "Jump to previous diagnostic", silent = true },
      ["]e"] = { "<cmd>Lspsaga diagnostic_jump_next<CR>", "Jump to next diagnostic", silent = true },
      ["[E"] = { jump_to_prev_error, "Jump to previous error", silent = true },
      ["]E"] = { jump_to_next_error, "Jump to next error", silent = true },
    })

    wk.register({
      name = "lspsaga commands",
      ca = { "<cmd>Lspsaga code_action<CR>", "Code action", mode = { "n", "v" }, silent = true },
      cd = { "<cmd>Lspsaga show_line_diagnostics<CR>", "Show line diagnostics", silent = true },
      ccd = { "<cmd>Lspsaga show_cursor_diagnostics<CR>", "Show cursor diagnostics", silent = true },
      o = { "<cmd>Lspsaga outline<CR>", "Objects outline", silent = true },
      sf = { "<cmd>Lspsaga finder<CR>", "Shows a list of references and implementations", silent = true },
    }, { prefix = "<leader>" })
  end,
}
