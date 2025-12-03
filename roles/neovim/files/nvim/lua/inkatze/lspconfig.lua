local M = {}

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

-- Helper function to setup LSP config and autocmd
M.setup_server = function(server_name, config, filetypes)
  -- Set the LSP config
  vim.lsp.config[server_name] = config

  -- Create autocmd to start LSP on appropriate filetypes
  vim.api.nvim_create_autocmd('FileType', {
    pattern = filetypes,
    callback = function(args)
      -- Get the config and merge with buffer info
      local lsp_config = vim.deepcopy(vim.lsp.config[server_name])
      lsp_config.name = server_name
      lsp_config.bufnr = args.buf

      -- Resolve root_dir if it's a function
      if type(lsp_config.root_dir) == 'function' then
        local bufname = vim.api.nvim_buf_get_name(args.buf)
        lsp_config.root_dir = lsp_config.root_dir(bufname) or vim.fn.getcwd()
      end

      vim.lsp.start(lsp_config)
    end,
  })
end

-- Backward compatibility: empty on_attach for plugins that expect it
-- The global LspAttach autocmd handles everything now
M.on_attach = function(client, bufnr)
  -- This is intentionally empty - LspAttach autocmd handles all setup
end

-- Global LspAttach autocmd - runs for ALL LSP servers
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    -- Autoformat on save if server supports it
    if client.server_capabilities.documentFormattingProvider then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr })
        end,
      })
    end

    -- Setup keybindings
    local wk = require("which-key")
    wk.add({
      { "<leader>l",   buffer = bufnr,                                                          group = "LSP commands",      remap = false },
      { "<leader>lK",  vim.lsp.buf.hover,                                                       buffer = bufnr,              desc = "Show documentation",       remap = false },
      { "<leader>lf",  vim.lsp.buf.format,                                                      buffer = bufnr,              desc = "Run code formatter",       remap = false },
      { "<leader>lg",  buffer = bufnr,                                                          group = "Go to definitions", remap = false },
      { "<leader>lgD", vim.lsp.buf.declaration,                                                 buffer = bufnr,              desc = "LSP go to declaration",    remap = false },
      { "<leader>lgd", vim.lsp.buf.definition,                                                  buffer = bufnr,              desc = "LSP go to definition",     remap = false },
      { "<leader>lgi", vim.lsp.buf.implementation,                                              buffer = bufnr,              desc = "LSP find implementation",  remap = false },
      { "<leader>lgr", vim.lsp.buf.references,                                                  buffer = bufnr,              desc = "LSP go to references",     remap = false },
      { "<leader>lk",  vim.lsp.buf.signature_help,                                              buffer = bufnr,              desc = "Show signature help",      remap = false },
      { "<leader>lr",  vim.lsp.buf.rename,                                                      buffer = bufnr,              desc = "Rename object",            remap = false },
      { "<leader>lt",  vim.lsp.buf.type_definition,                                             buffer = bufnr,              desc = "Show type definition",     remap = false },
      { "<leader>lw",  buffer = bufnr,                                                          group = "LSP workspace",     remap = false },
      { "<leader>lwa", vim.lsp.buf.add_workspace_folder,                                        buffer = bufnr,              desc = "Adds workspace folder",    remap = false },
      { "<leader>lwl", function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, buffer = bufnr,              desc = "Lists workspace folders",  remap = false },
      { "<leader>lwr", vim.lsp.buf.remove_workspace_folder,                                     buffer = bufnr,              desc = "Removes workspace folder", remap = false },
      { "<leader>lx",  vim.lsp.buf.code_action,                                                 buffer = bufnr,              desc = "Code action",              remap = false },
    })
  end,
})

return M
