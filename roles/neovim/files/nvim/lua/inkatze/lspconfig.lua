local M = {}

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

M.on_attach = function(client, bufnr)
  -- Autoformat on save for the given file patterns
  -- TODO: Conditional not working for some reason
  if client.server_capabilities.formatProvider then
    vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = augroup,
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.format({ bufnr = bufnr })
      end,
    })
  end

  require("lsp_signature").on_attach({
    bind = true,
    handler_opts = {
      border = "rounded"
    }
  }, bufnr)

  local wk = require("which-key")
  wk.add({
    { "<leader>l",   buffer = 1,                                                              group = "LSP commands",      remap = false },
    { "<leader>lK",  vim.lsp.buf.hover,                                                       buffer = 1,                  desc = "Show documentation",       remap = false },
    { "<leader>lf",  vim.lsp.buf.format,                                                      buffer = 1,                  desc = "Run code formatter",       remap = false },
    { "<leader>lg",  buffer = 1,                                                              group = "Go to definitions", remap = false },
    { "<leader>lgD", vim.lsp.buf.declaration,                                                 buffer = 1,                  desc = "LSP go to declaration",    remap = false },
    { "<leader>lgd", vim.lsp.buf.definition,                                                  buffer = 1,                  desc = "LSP go to definition",     remap = false },
    { "<leader>lgi", vim.lsp.buf.implementation,                                              buffer = 1,                  desc = "LSP find implementation",  remap = false },
    { "<leader>lgr", vim.lsp.buf.references,                                                  buffer = 1,                  desc = "LSP go to references",     remap = false },
    { "<leader>lk",  vim.lsp.buf.signature_help,                                              buffer = 1,                  desc = "Show signature help",      remap = false },
    { "<leader>lr",  vim.lsp.buf.rename,                                                      buffer = 1,                  desc = "Rename object",            remap = false },
    { "<leader>lt",  vim.lsp.buf.type_definition,                                             buffer = 1,                  desc = "Show type definition",     remap = false },
    { "<leader>lw",  buffer = 1,                                                              group = "LSP workspace",     remap = false },
    { "<leader>lwa", vim.lsp.buf.add_workspace_folder,                                        buffer = 1,                  desc = "Adds workspace folder",    remap = false },
    { "<leader>lwl", function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, buffer = 1,                  desc = "Lists workspace folders",  remap = false },
    { "<leader>lwr", vim.lsp.buf.remove_workspace_folder,                                     buffer = 1,                  desc = "Removes workspace folder", remap = false },
    { "<leader>lx",  vim.lsp.buf.code_action,                                                 buffer = 1,                  desc = "Code action",              remap = false },
  })
end

return M
