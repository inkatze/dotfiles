return {
  -- No config and support plugins
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "nvim-lua/plenary.nvim",       lazy = true },
  { "romgrk/barbar.nvim",          event = "BufRead" },
  { "tpope/vim-commentary",        event = "BufRead" },
  { "DanilaMihailov/beacon.nvim",  event = "BufRead" },
  { "mfussenegger/nvim-ansible",   ft = "yaml" },
  { 'echasnovski/mini.nvim',       version = '*' },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
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
    "ray-x/lsp_signature.nvim",
    event = "InsertEnter",
    opts = {
      bind = true,
      handler_opts = {
        border = "rounded"
      }
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      completions = { lsp = { enabled = true } },
    },
    ft = { "markdown", "codecompanion" }
  },
  {
    "HakonHarnes/img-clip.nvim",
    build = "brew install pngpaste",
    opts = {
      filetypes = {
        codecompanion = {
          prompt_for_file_name = false,
          template = "[Image]($FILE_PATH)",
          use_absolute_path = true,
        },
      },
    },
  },
  {
    "ravitemer/mcphub.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-lualine/lualine.nvim"
    },
    build = "mise x -- npm i -g mcp-hub@latest",
    opts = {
      cmd = "mise",
      cmdArgs = { "exec", "node", "--", "mcp-hub" },
    }
  }
}
