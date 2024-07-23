vim.opt_local.autoindent = true
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2

local base_dir = os.getenv("HOME") .. "/dev"
local jdtls_dir = base_dir .. "/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository"
local bundles = {
  vim.fn.glob(base_dir .. "/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar", true),
};
vim.list_extend(bundles, vim.split(vim.fn.glob(base_dir .. "/vscode-java-test/server/*.jar", true), "\n"))

local capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities = {
  workspace = { configuration = true },
  textDocument = {
    completion = {
      completionItem = {
        snippetSupport = true,
      },
    },
  },
}
capabilities.textDocument.completion.completionItem.snippetSupport = true

local config = {
  cmd = {
    jdtls_dir .. "/bin/jdtls",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-configuration", jdtls_dir .. "/config_mac_arm",
    "-data", os.getenv("HOME") .. "/.cache/jdtls/workspace"
  },
  root_dir = vim.fs.dirname(vim.fs.find({ 'gradlew', '.git', 'mvnw' }, { upward = true })[1]),
  capabilities = capabilities,
  on_attach = require("inkatze.lspconfig").on_attach,
  init_options = {
    bundles = bundles,
  }
}

require('jdtls').start_or_attach(config)
