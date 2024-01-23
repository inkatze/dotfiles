local M = {}

M.setup = function()
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
      "-jar",
      "/Users/diego.romero/dev/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/plugins/org.eclipse.equinox.launcher_1.6.700.v20231214-2017.jar",
      "-configuration",
      "/Users/diego.romero/dev/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/config_mac_arm",
      "-data",
      "/Users/diego.romero/.cache/jdtls/workspace"
    },
  })
end

return M
