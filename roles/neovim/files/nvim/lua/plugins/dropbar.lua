return {
  "Bekaboo/dropbar.nvim",
  event = "LspAttach",
  enabled = false,
  dependencies = { "folke/which-key.nvim" },
  config = function()
    require("dropbar").setup()
    require("which-key").add({
      { "<leader>d", group = "Dropbar commands" },
      { "<leader>dp", vim.diagnostic.setloclist, desc = "Set loc list" }
    })
  end,
}
