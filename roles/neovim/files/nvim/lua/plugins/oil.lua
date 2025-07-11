local ignored = {
  '.git',
  '.svn',
  '.hg',
  '.DS_Store',
  'node_modules',
  'vendor',
  '__pycache__',
}

return {
  'stevearc/oil.nvim',
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    view_options ={
      show_hidden = true,
      is_always_hidden = function(name) return vim.tbl_contains(ignored, name) end,
    }
  },
  dependencies = { { "echasnovski/mini.icons", opts = {} } },
  lazy = false,
  config = function(_, opts)
    require('oil').setup(opts)
    vim.api.nvim_create_user_command('OilToggle', function()
      vim.cmd((vim.bo.filetype == 'oil') and 'bd' or 'Oil .')
    end, { nargs = 0 })
    require('which-key').add({
      { "-", "<cmd>Oil<cr>", mode = "n", desc = "Open Oil" },
      { "<c-n>", "<cmd>OilToggle<cr>", mode = "n", desc = "Toggle Oil" },
    })
  end
}
