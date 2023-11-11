return {
  "nvim-neotest/neotest",
  ft = { "ruby", "elixir", "javascript", "javascriptreact", "typescript", "typescriptreact" },
  dependencies = {
    { "olimorris/neotest-rspec",  lazy = true },
    { "jfpedroza/neotest-elixir", lazy = true },
    { "haydenmeade/neotest-jest", lazy = true },
    { "folke/which-key.nvim",     lazy = true },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-rspec"),
        require("neotest-elixir"),
        require("neotest-jest")({
          jestCommand = "npm test --",
          jestConfigFile = "custom.jest.config.ts",
          env = { CI = true },
          cwd = function(_)
            return vim.fn.getcwd()
          end,
        }),
      },
    })

    require("which-key").register({
      nt = {
        name = "neotest",
        r = { "<cmd>lua require('neotest').run.run()<cr>", "Run test under the cursor" },
        f = { "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<cr>", "Run file" },
      },
    }, { prefix = "<leader>" })
  end,
}
