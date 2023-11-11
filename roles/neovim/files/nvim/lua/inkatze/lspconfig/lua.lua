local M = {}

local runtime_path = vim.split(package.path, ";")

M.setup = function()
  require("lspconfig").lua_ls.setup({
    filetypes = { "lua" },
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    on_attach = function(client, bufnr)
      require("inkatze.lspconfig").on_attach(client, bufnr)
      -- Lets null-ls and stylua take care of formatting
      client.server_capabilities.document_formatting = false
      client.server_capabilities.document_range_formatting = false
    end,
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
      },
    },
  })
end

return M
