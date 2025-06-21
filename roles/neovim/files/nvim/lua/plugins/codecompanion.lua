return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/mcphub.nvim"
  },
  config = function(_, _)
    local wk = require("which-key")
    wk.add({
      { "<leader>cc",  group = "CodeCompanion" },
      { "<leader>cca", "<cmd>CodeCompanionActions<cr>",     desc = "CodeCompanion actions" },
      { "<leader>ccc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion chat toggle" },
      { "<leader>cca", "<cmd>CodeCompanionChat Add<cr>",    desc = "CodeCompanion chat add selection", mode = "v" },
    })

    require("codecompanion").setup({
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
      display = {
        chat = {
          window = {
            position = "right",
          }
        }
      },
      adapters = {
        anthropic = function()
          -- Check for environment variable first
          local api_key = os.getenv("ANTHROPIC_API_KEY")

          return require("codecompanion.adapters").extend("anthropic", {
            env = {
              -- Use env var if set, otherwise fall back to 1Password
              api_key = api_key or "cmd:op read 'op://Private/Anthropic API key/credential' --no-newline",
            },
            schema = {
              model = {
                default = "claude-opus-4-20250514",
              },
            },
          })
        end,
      },
      strategies = {
        chat = {
          adapter = "anthropic",
        },
        inline = {
          adapter = "anthropic",
        },
        cmd = {
          adapter = "anthropic",
        }
      },
    })
  end
}
