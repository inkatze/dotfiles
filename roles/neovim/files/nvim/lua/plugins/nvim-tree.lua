return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false,
  dependencies = { "folke/which-key.nvim" },
  config = function()
    local ignore_list = { "\\.git$", "node_modules$", ".cache" }
    local tree = require("nvim-tree")

    tree.setup({
      diagnostics = {
        enable = true,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
      git = {
        enable = true,
        ignore = false,
        timeout = 300,
      },
      update_focused_file = {
        enable = true,
        update_cwd = true,
        ignore_list = ignore_list,
      },
      view = {
        adaptive_size = true,
      },
      renderer = {
        highlight_opened_files = "all",
        highlight_git = true,
        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
          },
        },
      },
      filters = {
        custom = ignore_list,
      },
    })

    require("which-key").add({
      { "<c-t>", "<cmd>NvimTreeToggle<cr>", desc = "Toggles nvim-tree", remap = false },
    })
  end,
}
