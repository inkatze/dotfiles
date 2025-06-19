return {
  "olimorris/codecompanion.nvim",
  opts = {
    extensions = {
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          make_vars = true,
          make_slash_commands = true,
          show_result_in_chat = true
        }
      }
    },
    adapters = {
      copilot = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "MY_OTHER_ANTHROPIC_KEY",
          },
        })
      end
    },
    display = {
      chat = {
        window = {
          position = "right",
        }
      }
    }
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/mcphub.nvim"
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.add({
      { "<leader>cc",  group = "CodeCompanion" },
      { "<leader>cca", "<cmd>CodeCompanionActions<cr>",     desc = "CodeCompanion actions" },
      { "<leader>ccc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion chat toggle" },
      { "<leader>cca", "<cmd>CodeCompanionChat Add<cr>",    desc = "CodeCompanion chat add selection" },
    })
    require("codecompanion").setup(opts)
  end
}
