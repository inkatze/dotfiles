return {
  -- Fancy symbol trees for syntax and others
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = "all", -- one of "all" or a list of languages
    ignore_install = { "phpdoc" },
    sync_install = false,
    auto_install = true,
    modules = {},
    highlight = {
      enable = true, -- false will disable the whole extension
      additional_vim_regex_highlighting = false,
    },
    indent = {
      enable = true,
    },
    autopairs = { -- Used by nvim-autopair
      enable = true,
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_incremental = "grn",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
    },
  },
  config = function()
    -- Folding
    vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufNew", "BufNewFile", "BufWinEnter" }, {
      group = vim.api.nvim_create_augroup("TS_FOLD_WORKAROUND", {}),
      callback = function()
        vim.opt.foldmethod = "expr"
        vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
        vim.opt.foldlevel = 99
      end,
    })
  end,
  build = function()
    vim.fn.system({ "brew", "install", "tree-sitter" })
    local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
    ts_update()
  end,
}
