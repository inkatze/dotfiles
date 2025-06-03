vim.opt_local.autoindent = true
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4

local base_dir = os.getenv("HOME") .. "/dev"
local jdtls_dir = base_dir .. "/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository"

local bundles = {}
for _, jar in ipairs(vim.split(vim.fn.glob(
  base_dir .. "/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar",
  true
), "\n")) do
  if #jar > 0 then
    table.insert(bundles, jar)
  end
end
-- vim.list_extend(bundles, vim.split(vim.fn.glob(base_dir .. "/vscode-java-test/server/*.jar", true), "\n"))

local project_root = vim.fs.dirname(vim.fs.find({ 'gradlew', '.git', 'mvnw' }, { upward = true })[1])
local workspace = os.getenv("HOME") .. "/.cache/jdtls/workspace"

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
    "mise", "exec", "--", "java",
    "--enable-preview",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.level=ALL",
    "-Xmx2G",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", jdtls_dir .. "/plugins/org.eclipse.equinox.launcher_1.7.0.v20250519-0528.jar",
    "-configuration", jdtls_dir .. "/config_mac_arm",
    "-data", workspace
  },
  root_dir = project_root,
  capabilities = capabilities,
  on_attach = require("inkatze.lspconfig").on_attach,
  init_options = {
    bundles = bundles,
  },
  settings = {
    java = {
      import = {
        gradle = {
          enabled = true,
          wrapper = {
            enabled = true,
          },
          annotationProcessing = {
            enabled = true,
          },
        },
      },
    }
  }
}

require('jdtls').start_or_attach(config)
