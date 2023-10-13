return {
  "nvim-tree/nvim-tree.lua",
  version = "nightly", -- optional, updated every week. (see issue #1193)
  dependencies = { "folke/which-key.nvim" },
  config = function()
    local ignore_list = { ".git$", "node_modules$", ".cache" }
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
        update_cwd = false,
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

    require("which-key").register({
      name = "Nvim tree file explorer",
      ["<c-n>"] = { "<cmd>NvimTreeToggle<cr>", "Toggles nvim-tree", noremap = true, silent = true },
    })
  end,
}
