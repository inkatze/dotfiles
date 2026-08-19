return {
  "nvim-lualine/lualine.nvim",
  event = "BufRead",
  config = function()
    require("lualine").setup({
      options = {
        -- catppuccin ships its lualine theme as catppuccin-nvim (it follows
        -- the active flavour); there is no plain "catppuccin" module, so that
        -- name silently resolved to the "auto" fallback.
        theme = "catppuccin-nvim",
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
