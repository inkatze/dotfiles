local M = {}

M.setup = function()
  local base = require("inkatze.lspconfig")

  base.setup_server('gradle_ls', {
    cmd = { "/Users/diego.romero/dev/vscode-gradle/gradle-language-server/build/install/gradle-language-server/bin/gradle-language-server" },
    root_dir = function(fname)
      return vim.fs.root(fname, { 'settings.gradle', 'settings.gradle.kts' })
    end,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    settings = {
      gradleWrapperEnabled = true
    }
  }, { 'gradle' })
end

return M
