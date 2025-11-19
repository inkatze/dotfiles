local M = {}

local runtime_path = vim.split(package.path, ";")

M.setup = function()
  local base = require("inkatze.lspconfig")

  base.setup_server('lua_ls', {
    cmd = { 'lua-language-server' },
    root_dir = function(fname)
      return vim.fs.root(fname,
        { '.luarc.json', '.luarc.jsonc', '.luacheckrc', '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml',
          '.git' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    settings = {
      Lua = {
        runtime = {
          -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
          version = "LuaJIT",
          -- Setup your lua path
          path = runtime_path,
        },
        diagnostics = {
          -- Get the language server to recognize the `vim` global
          globals = { "vim" },
        },
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = false,
        },
        -- Do not send telemetry data containing a randomized but unique identifier
        telemetry = {
          enable = false,
        },
        format = {
          enable = true,
          defaultConfig = {
            indent_style = "space",
            indent_size = "2",
            quote_style = "double",
            align_line_wrapped = true,
          },
        },
      },
    },
  }, { 'lua' })
end

return M
