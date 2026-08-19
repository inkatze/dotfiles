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

  -- sorbet configuration. Keyed on sorbet/config rather than on Gemfile or
  -- .git: both of those match ruby checkouts that have no sorbet in the
  -- bundle, where `bundle exec srb` exits 10 the moment it starts.
  base.setup_server('sorbet', {
    cmd = { "bundle", "exec", "srb", "tc", "--lsp" },
    root_dir = function(fname)
      return vim.fs.root(fname, { 'sorbet/config' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  }, { 'ruby' })

  -- rubocop configuration. Same reasoning as sorbet above: .rubocop.yml is
  -- what says this project actually runs rubocop.
  base.setup_server('rubocop', {
    cmd = { "bundle", "exec", "rubocop", "--lsp" },
    root_dir = function(fname)
      return vim.fs.root(fname, { '.rubocop.yml' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
  }, { 'ruby' })
end

return M
