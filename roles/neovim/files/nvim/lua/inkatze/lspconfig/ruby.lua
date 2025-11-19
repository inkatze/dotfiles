local M = {}

M.setup = function()
  local base = require("inkatze.lspconfig")

  -- ruby_lsp configuration
  base.setup_server('ruby_lsp', {
    cmd = { 'ruby-lsp' },
    root_dir = function(fname)
      return vim.fs.root(fname, { 'Gemfile', '.git' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  }, { 'ruby' })

  -- sorbet configuration
  base.setup_server('sorbet', {
    cmd = { "bundle", "exec", "srb", "tc", "--lsp" },
    root_dir = function(fname)
      return vim.fs.root(fname, { 'Gemfile', '.git' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  }, { 'ruby' })

  -- rubocop configuration
  base.setup_server('rubocop', {
    cmd = { "bundle", "exec", "rubocop", "--lsp" },
    root_dir = function(fname)
      return vim.fs.root(fname, { '.rubocop.yml', 'Gemfile', '.git' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  }, { 'ruby' })
end

return M
