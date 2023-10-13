local M = {}

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

M.on_attach = function(_client, bufnr)
  -- Autoformat on save for the given file patterns
  -- TODO: Conditional not working for some reason
  -- if client.server_capabilities.formatProvider then
  vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      vim.lsp.buf.format({ bufnr = bufnr })
    end,
  })
  -- end

  local wk = require("which-key")
  wk.register({
    l = {
      name = "LSP commands",
      f = { vim.lsp.buf.format, "Run code formatter" },
      g = {
        name = "Go to definitions",
        d = { vim.lsp.buf.definition, "LSP go to definition" },
        D = { vim.lsp.buf.declaration, "LSP go to declaration" },
        r = { vim.lsp.buf.references, "LSP go to references" },
        i = { vim.lsp.buf.implementation, "LSP find implementation" },
      },
      K = { vim.lsp.buf.hover, "Show documentation" },
      k = { vim.lsp.buf.signature_help, "Show signature help" },
      r = { vim.lsp.buf.rename, "Rename object" },
      t = { vim.lsp.buf.type_definition, "Show type definition" },
      w = {
        name = "LSP workspace",
        a = { vim.lsp.buf.add_workspace_folder, "Adds workspace folder" },
        r = { vim.lsp.buf.remove_workspace_folder, "Removes workspace folder" },
        l = {
          function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end,
          "Lists workspace folders",
        },
      },
      x = { vim.lsp.buf.code_action, "Code action" },
    },
  }, { prefix = "<leader>", silent = true, noremap = true, buffer = bufnr })
end

return M
