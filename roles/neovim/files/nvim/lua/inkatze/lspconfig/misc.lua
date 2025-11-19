local M = {}

local servers = {
  angularls = {
    cmd = { 'ngserver', '--stdio', '--tsProbeLocations', '.', '--ngProbeLocations', '.' },
    filetypes = { 'typescript', 'html', 'typescriptreact', 'typescript.tsx' },
    root_markers = { 'angular.json', 'project.json' },
  },
  bashls = {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh' },
    root_markers = { '.git' },
  },
  basedpyright = {
    cmd = { 'basedpyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', '.git' },
  },
  graphql = {
    cmd = { 'graphql-lsp', 'server', '-m', 'stream' },
    filetypes = { 'graphql', 'typescriptreact', 'javascriptreact' },
    root_markers = { '.graphqlrc*', '.graphql.config.*', 'graphql.config.*', '.git' },
  },
  jsonls = {
    cmd = { 'vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    root_markers = { '.git' },
  },
  pyright = {
    cmd = { 'pyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', '.git' },
  },
  stylelint_lsp = {
    cmd = { 'stylelint-lsp', '--stdio' },
    filetypes = { 'css', 'scss', 'less', 'sass' },
    root_markers = { '.stylelintrc', '.stylelintrc.json', '.stylelintrc.js', 'stylelint.config.js', '.git' },
  },
  tailwindcss = {
    cmd = { 'tailwindcss-language-server', '--stdio' },
    filetypes = { 'html', 'css', 'scss', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'tailwind.config.js', 'tailwind.config.ts', 'tailwind.config.cjs', '.git' },
  },
  terraformls = {
    cmd = { 'terraform-ls', 'serve' },
    filetypes = { 'terraform', 'tf' },
    root_markers = { '.terraform', '.git' },
  },
  ts_ls = {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact', 'typescript.tsx' },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
  },
  vimls = {
    cmd = { 'vim-language-server', '--stdio' },
    filetypes = { 'vim' },
    root_markers = { '.git' },
  },
}

M.setup = function()
  local base = require("inkatze.lspconfig")

  for server_name, server_config in pairs(servers) do
    local filetypes = server_config.filetypes
    local root_markers = server_config.root_markers

    -- Create config with root_dir as a function
    local config = {
      cmd = server_config.cmd,
      root_dir = function(fname)
        return vim.fs.root(fname, root_markers)
      end,
      capabilities = require("cmp_nvim_lsp").default_capabilities(),
    }

    base.setup_server(server_name, config, filetypes)
  end
end

return M
