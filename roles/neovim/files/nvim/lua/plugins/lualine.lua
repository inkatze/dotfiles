return {
  "nvim-lualine/lualine.nvim",
  event = "BufRead",
  dependencies = {
    "ravitemer/mcphub.nvim",
  },
  config = function()
    require("lualine").setup({
      options = {
        theme = "catppuccin",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          "branch",
          "diff",
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            symbols = { error = " ", warn = " ", info = " ", hint = " " },
          },
        },
        lualine_c = { "filename" },
        lualine_x = {
          { require('inkatze.lualine.components.codecompanion') }, -- these requires prevent us from putting these as opts
          { require('mcphub.extensions.lualine') },
          "encoding",
          "fileformat",
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      extensions = { "quickfix", "nvim-tree" },
    })
  end,
}
