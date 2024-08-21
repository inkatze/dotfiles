local mappings = function()
  local builtin = require("telescope.builtin")
  local wk = require("which-key")

  wk.add({
    { "<leader>t",    group = "Telescope actions" },
    { "<leader>tb",   builtin.buffers,            desc = "Find buffers" },
    { "<leader>tf",   builtin.find_files,         desc = "Find files" },
    { "<leader>tg",   group = "Telescope git" },
    { "<leader>tgbc", builtin.git_bcommits,       desc = "Git buffer commits" },
    { "<leader>tgbr", builtin.git_branches,       desc = "Git branches" },
    { "<leader>tgc",  builtin.git_commits,        desc = "Git commits" },
    { "<leader>tgf",  builtin.git_files,          desc = "Git files" },
    { "<leader>tgs",  builtin.git_status,         desc = "Git status" },
    { "<leader>tgx",  builtin.git_stash,          desc = "Git stash" },
    { "<leader>th",   builtin.help_tags,          desc = "Help tags" },
    { "<leader>ts",   builtin.live_grep,          desc = "Live grep" },
    { "<c-b>", builtin.buffers,    desc = "Find buffers" },
    { "<c-f>", builtin.find_files, desc = "Find files" },
    { "<c-s>", builtin.live_grep,  desc = "Live grep" },
  })

  require('telescope').setup({
    defaults = {
      layout_strategy = 'vertical',
      layout_config = { prompt_position = "top" },
      sorting_strategy = "ascending",
      winblend = 0,
      file_ignore_patterns = { "node%_modules/.*",
        "%.rbi",
        "log/.*",
        "tmp/.*",
        "ar%_doc/",
        "assets/vendor/",
        "**/*.class",
        "**/rubygems",
        "**/build",
        "**/dist",
        "**/target",
        "**/bin",
      },
    }
  })
end

return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    { "nvim-lua/plenary.nvim", lazy = true },
    { "folke/which-key.nvim",  lazy = true }
  },
  config = mappings,
}
