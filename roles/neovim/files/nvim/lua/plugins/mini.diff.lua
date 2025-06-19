return {
  'echasnovski/mini.nvim',
  version = false,
  config = function()
    local diff = require('mini.diff')
    diff.setup({
      source = diff.gen_source.none(),
    })
  end,
}
