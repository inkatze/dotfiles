return {
  -- No config and support plugins
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "nvim-lua/plenary.nvim",       lazy = true },
  { "romgrk/barbar.nvim",          event = "BufRead" },
  { "tpope/vim-commentary",        event = "BufRead" },
  { "DanilaMihailov/beacon.nvim",  event = "BufRead" },
  { "mfussenegger/nvim-ansible",   ft = "yaml" },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "folke/trouble.nvim",
    event = "BufRead",
    opts = {
      auto_close = true,
    },
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap" }
  },
  {
    "github/copilot.vim",
    event = "BufRead",
    build = ":Copilot setup",
  },
  { "tpope/vim-projectionist", event = "BufRead" },
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      -- Options related to integrating with other plugins
      integration = {
        ["nvim-tree"] = {
          enable = false, -- Integrate with nvim-tree/nvim-tree.lua (if installed)
        },
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
        delay = 1000,
        ignore_whitespace = false,
      },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
    },
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "BufRead",
    opts = { scope = { enabled = true } },
  },
}
