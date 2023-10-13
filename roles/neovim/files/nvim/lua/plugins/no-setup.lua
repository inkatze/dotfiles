return {
  -- No config and support plugins
  { "kyazdani42/nvim-web-devicons", lazy = true },
  { "nvim-lua/plenary.nvim",        lazy = true },
  { "romgrk/barbar.nvim",           event = "BufAdd" },
  { "tpope/vim-commentary",         event = "BufAdd" },
  { "DanilaMihailov/beacon.nvim",   event = "BufAdd" },
  { "mfussenegger/nvim-ansible",    ft = "yaml" },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "folke/trouble.nvim",
    event = "BufAdd",
    opts = {
      auto_close = true,
    },
  },
  {
    "mfussenegger/nvim-dap",
    event = "BufAdd",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      lazy = true,
      opts = {},
    }
  },
  {
    "github/copilot.vim",
    event = "BufAdd",
    build = ":Copilot setup",
  },
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    build = "./scripts/link_mac.sh && mvn package -DskipTests",
  },
  { "tpope/vim-projectionist", event = "BufAdd" },
  {
    "j-hui/fidget.nvim",
    version = "legacy",
    event = "LspAttach",
    opts = {},
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
    event = "BufAdd",
    opts = { scope = { enabled = false } },
  },
}
