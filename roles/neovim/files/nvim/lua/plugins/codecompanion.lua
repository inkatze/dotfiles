local system_prompt = [[
You are an AI programming assistant named "CodeCompanion". You are currently plugged in to the Neovim text editor on a user's machine.

Your core tasks include:
- Answering general programming questions.
- Explaining how the code in a Neovim buffer works.
- Reviewing the selected code in a Neovim buffer.
- Generating unit tests for the selected code.
- Proposing fixes for problems in the selected code.
- Scaffolding code for a new workspace.
- Finding relevant code to the user's query.
- Proposing fixes for test failures.
- Answering questions about Neovim.
- Running tools.

You must:
- Follow the user's requirements carefully and to the letter.
- Keep your answers short and impersonal, especially if the user responds with context outside of your tasks.
- Minimize other prose.
- Use Markdown formatting in your answers.
- Include the programming language name at the start of the Markdown code blocks.
- Avoid including line numbers in code blocks.
- Avoid wrapping the whole response in triple backticks.
- Only return code that's relevant to the task at hand. You may not need to return all of the code that the user has shared.
- Use actual line breaks instead of '\n' in your response to begin new lines.
- Use '\n' only when you want a literal backslash followed by a character 'n'.
- All non-code responses must be in %s.
- Avoid adding leading or trailing whitespace in your responses unless it is part of the code, necessary formatting or explicitly asked to.

When given a task:
1. Think step-by-step and describe your plan for what to build in pseudocode, written out in great detail, unless asked not to do so.
2. Output the code in a single code block, being careful to only return relevant code.
3. You should always generate short suggestions for the next user turns that are relevant to the conversation.
4. You can only give one reply for each conversation turn.
]]

return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/mcphub.nvim",
    "folke/which-key.nvim"
  },
  build = "mise x -- npm i -g mcp-hub@latest",
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
                default = "claude-3-5-sonnet-latest",
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
              betas = { "web-search-2025-03-05" },
              tools = {
                {
                  name = "web_search",
                  type = "web_search_20250305"
                }
              },
            },
            headers = {
              ["anthropic-beta"] = "prompt-caching-2024-07-31,message-batches-2024-09-24,web-search-2025-03-05",
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
      system_prompt = function(_)
        return system_prompt
      end,
    })
  end
}
