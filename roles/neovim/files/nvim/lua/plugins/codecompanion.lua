return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/mcphub.nvim",
    "folke/which-key.nvim"
  },
  config = function(_, _)
    local wk = require("which-key")
    wk.add({
      { "<leader>cc",  group = "CodeCompanion" },
      { "<leader>cca", "<cmd>CodeCompanionActions<cr>",     desc = "CodeCompanion actions" },
      { "<leader>ccc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion chat toggle" },
      {
        "<leader>cca",
        "<cmd>CodeCompanionChat Add<cr>",
        desc = "Add to CodeCompanion",
        mode = "v"
      },
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
      completion = {
        enabled = true,
        trigger_characters = { "." },
        auto_trigger = true
      },
      adapters = {
        anthropic = function()
          local api_key = os.getenv("ANTHROPIC_API_KEY")

          return require("codecompanion.adapters").extend("anthropic", {
            env = {
              api_key = api_key or "cmd:op read 'op://Private/Anthropic API key/credential' --no-newline",
            },
            schema = {
              model = {
                default = "claude-3-5-sonnet-20241022",
              },
              max_tokens = {
                default = 8192,
              },
              temperature = {
                default = 0.2,
              },
              thinking = {
                type = "enabled",
                ["budget_tokens"] = 12000
              },
            },
            headers = {
              ["anthropic-beta"] = "prompt-caching-2024-07-31,message-batches-2024-09-24",
            },
            cache_control = {
              -- Enable caching for system messages
              system = {
                type = "ephemeral"
              },
              -- Cache large code contexts and file contents
              user = function(message)
                -- Cache messages with attachments (file contents)
                if message.attachments and #message.attachments > 0 then
                  return { type = "ephemeral" }
                end
                -- Cache messages over 500 characters (likely code snippets)
                if message.content and #message.content > 500 then
                  return { type = "ephemeral" }
                end
                return nil
              end,
            },
          })
        end,
        anthropic_fast = function()
          local api_key = os.getenv("ANTHROPIC_API_KEY")

          return require("codecompanion.adapters").extend("anthropic", {
            env = {
              api_key = api_key or "cmd:op read 'op://Private/Anthropic API key/credential' --no-newline",
            },
            schema = {
              model = {
                -- Claude 3 Haiku for quick, simple tasks
                default = "claude-3-haiku-20240307",
              },
              max_tokens = {
                default = 4096,
              },
              temperature = {
                default = 0.1,
              },
            },
            headers = {
              ["anthropic-beta"] = "prompt-caching-2024-07-31",
            },
            cache_control = {
              system = {
                type = "ephemeral"
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
          adapter = "anthropic_fast",
        },
        cmd = {
          adapter = "anthropic_fast",
        }
      },
      -- Optional: Configure system prompts to be more cache-friendly
      prompts = {
        ["Code Review"] = {
          strategy = "chat",
          description = "Review the selected code",
          opts = {
            system_prompt = [[You are an expert code reviewer. Focus on:
- Code quality and best practices
- Performance implications
- Security concerns
- Maintainability
- Potential bugs

This prompt is cached for efficiency.]],
          },
        },
        ["Generate Tests"] = {
          strategy = "chat",
          description = "Generate unit tests for the selected code",
          opts = {
            system_prompt = [[You are an expert test engineer. Generate comprehensive unit tests that:
- Cover edge cases
- Follow testing best practices
- Use appropriate testing frameworks
- Include both positive and negative test cases

This prompt is cached for efficiency.]],
          },
        },
      },
    })
  end
}
