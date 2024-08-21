return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  dependencies = {
    "echasnovski/mini.icons",
  },
  config = function()
    local wk = require("which-key")

    wk.setup({
      plugins = {
        marks = true,       -- shows a list of your marks on ' and `
        registers = true,   -- shows your registers on " in NORMAL or <C-r> in INSERT mode
        spelling = {
          enabled = false,  -- enabling this will show WhichKey when pressing z= to select spelling suggestions
          suggestions = 20, -- how many suggestions should be shown in the list?
        },
        -- the presets plugin, adds help for a bunch of default keybindings in Neovim
        -- No actual key bindings are created
        presets = {
          operators = true,    -- adds help for operators like d, y, ... and registers them for motion / text object completion
          motions = true,      -- adds help for motions
          text_objects = true, -- help for text objects triggered after entering an operator
          windows = true,      -- default bindings on <c-w>
          nav = true,          -- misc bindings to work with windows
          z = true,            -- bindings for folds, spelling and others prefixed with z
          g = true,            -- bindings for prefixed with g
        },
      },
      icons = {
        breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
        separator = "➜", -- symbol used between a key and it's label
        group = "+", -- symbol prepended to a group
      },
      win = {
        -- don't allow the popup to overlap with the cursor
        no_overlap = true,
        -- width = 1,
        -- height = { min = 4, max = 25 },
        -- col = 0,
        -- row = math.huge,
        -- border = "none",
        padding = { 1, 2 }, -- extra window padding [top/bottom, right/left]
        title = true,
        title_pos = "center",
        zindex = 1000,
        -- Additional vim.wo and vim.bo options
        bo = {},
        wo = {},
      },
      layout = {
        height = { min = 4, max = 25 }, -- min and max height of the columns
        width = { min = 20, max = 50 }, -- min and max width of the columns
        spacing = 3,                    -- spacing between columns
        align = "left",                 -- align columns left, center or right
      },
      show_help = true,                 -- show help message on the command line when the popup is visible
      show_keys = true,                 -- show the currently pressed key and its label as a message in the command line
      triggers = {
        { "<auto>", mode = "nixsotc" },
        { "a",      mode = { "n", "v" } },
      },
      -- disable the WhichKey popup for certain buf types and file types.
      -- Disabled by deafult for Telescope
      disable = {
        buftypes = {},
        filetypes = { "TelescopePrompt" },
      },
    })

    -- General mappings
    local opts = { noremap = true, silent = true }
    wk.add({
      { "<s-left>",   "<cmd>BufferPrevious<cr>",                    desc = "Previous buffer" },
      { "<s-right>",  "<cmd>BufferNext<cr>",                        desc = "Next buffer" },
      { "<leader>",   group = "Search" },
      { "<leader>hl", "<cmd>nohl<cr>",                              desc = "Disable highlighting" },
      { "<leader>c",  group = "Copy current register relative path" },
      { "<leader>cP", "<cmd>CpPathClipboard<cr>",                   desc = "Copy relative path to clipboard" },
      { "<leader>cp", "<cmd>CpPath<cr>",                            desc = "Copy relative path to default register" },
    })
  end,
}
