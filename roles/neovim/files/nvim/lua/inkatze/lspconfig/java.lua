local M = {}

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

M.setup = function()
  local jdtls_dir = os.getenv("HOME") .. "/dev/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository"
  require("lspconfig").jdtls.setup({
    cmd = {
      "java",
      "-Declipse.application=org.eclipse.jdt.ls.core.id1",
      "-Dosgi.bundles.defaultStartLevel=4",
      "-Declipse.product=org.eclipse.jdt.ls.core.product",
      "-Dlog.level=ALL",
      "-Xmx1G",
      "--add-modules=ALL-SYSTEM",
      "--add-opens", "java.base/java.util=ALL-UNNAMED",
      "--add-opens", "java.base/java.lang=ALL-UNNAMED",
      "-jar", jdtls_dir .. "/plugins/org.eclipse.equinox.launcher_1.6.700.v20231214-2017.jar",
      "-configuration", jdtls_dir .. "/config_mac_arm",
      "-data", os.getenv("HOME") .. "/.cache/jdtls/workspace"
    },
    capabilities = capabilities,
    on_attach = require("inkatze.lspconfig").on_attach,
  })
end

return M
