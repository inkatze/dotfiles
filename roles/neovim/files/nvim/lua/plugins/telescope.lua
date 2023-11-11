local mappings = function()
  local builtin = require("telescope.builtin")
  local opts = { noremap = true, silent = true }
  local wk = require("which-key")

  wk.register({
    t = {
      name = "Telescope actions",                     -- optional group name
      b = { builtin.buffers, "Find buffers", opts },
      f = { builtin.find_files, "Find files", opts }, -- create a binding with label
      s = { builtin.live_grep, "Live grep", opts },
      h = { builtin.help_tags, "Help tags", opts },
      g = {
        name = "Telescope git",
        bc = { builtin.git_bcommits, "Git buffer commits", opts },
        br = { builtin.git_branches, "Git branches", opts },
        c = { builtin.git_commits, "Git commits", opts },
        f = { builtin.git_files, "Git files", opts },
        s = { builtin.git_status, "Git status", opts },
        x = { builtin.git_stash, "Git stash", opts },
      },
    },
  }, { prefix = "<leader>" })
  wk.register({
    name = "Telescope quick actions",
    ["<c-b>"] = { builtin.buffers, "Find buffers", opts },
    ["<c-f>"] = { builtin.find_files, "Find files", opts },
    ["<c-s>"] = { builtin.live_grep, "Live grep", opts },
  })
end

return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = { { "nvim-lua/plenary.nvim", lazy = true }, { "folke/which-key.nvim", lazy = true } },
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      file_ignore_patterns = { "node%_modules/.*", "%.rbi", "log/.*", "tmp/.*", "ar%_doc/", "assets/vendor/" },
    },
  },
  config = mappings,
}
