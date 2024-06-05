local M = {}

M.setup = function()
  require("lspconfig").gradle_ls.setup({
    cmd = { "/Users/diego.romero/dev/vscode-gradle/gradle-language-server/build/install/gradle-language-server/bin/gradle-language-server" },
    settings = {
      gradleWrapperEnabled = true
    }
  })
end

return M
