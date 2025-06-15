return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile", "BufWritePost", "InsertLeave" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      elixir = { "credo" },
    }

    local lint_group = vim.api.nvim_create_augroup("nvim_lint", { clear = true })

    -- Trigger linting on buffer read, write, and insert leave
    vim.api.nvim_create_autocmd(
      { "BufReadPost", "BufWritePost", "InsertLeave" },
      {
        group = lint_group,
        callback = function()
          lint.try_lint()
        end,
      }
    )
  end,
}
