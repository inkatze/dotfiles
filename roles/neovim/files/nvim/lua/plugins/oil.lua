return {
  'stevearc/oil.nvim',
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {},
  -- Optional dependencies
  dependencies = { { "echasnovski/mini.icons", opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  config = function(_, opts)
    require('oil').setup(opts)
    vim.api.nvim_create_user_command('OilToggle', function()
      vim.cmd((vim.bo.filetype == 'oil') and 'bd' or 'Oil')
    end, { nargs = 0 })
    require('which-key').add({
      { "-", "<cmd>Oil<cr>", mode = "n", desc = "Open Oil" },
      { "<c-n>", "<cmd>OilToggle<cr>", mode = "n", desc = "Toggle Oil" },
    })
  end
}
