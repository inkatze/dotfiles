vim.opt_local.autoindent = true
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4

-- jdtls comes from the packaged launcher on PATH (Homebrew's `jdtls` formula,
-- which wraps upstream's own bin/jdtls). That launcher picks the platform
-- config directory and the equinox launcher jar itself, which is what the
-- previous hand-built ~/dev/eclipse.jdt.ls setup hardcoded: a pinned
-- launcher-jar filename that a rebuild invalidated, and config_mac_arm, which
-- left the Linux host with no working java LSP at all.
if vim.fn.executable("jdtls") == 0 then
  return
end

-- Without a project marker there is nothing for jdtls to index, and
-- vim.fs.dirname(nil) would error outright.
local project_marker = vim.fs.find({ 'gradlew', 'mvnw', 'pom.xml', 'build.gradle', '.git' }, {
  upward = true,
  path = vim.api.nvim_buf_get_name(0),
})[1]

if not project_marker then
  return
end

local project_root = vim.fs.dirname(project_marker)

-- One workspace per project: jdtls keeps mutable index state here, and
-- pointing every project at a single directory (which is what this used to do)
-- makes it thrash. Named for the directory, disambiguated by a digest of the
-- full path, so two checkouts that happen to share a basename get a workspace
-- each instead of corrupting one between them.
local workspace = table.concat({
  vim.fn.stdpath("cache"),
  "jdtls/workspace",
  vim.fn.fnamemodify(project_root, ":t") .. "-" .. vim.fn.sha256(project_root):sub(1, 12),
}, "/")

-- java-debug is optional; an absent checkout just means no debug adapter.
local bundles = {}
for _, jar in ipairs(vim.split(vim.fn.glob(
  os.getenv("HOME") .. "/dev/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar",
  true
), "\n")) do
  if #jar > 0 then
    table.insert(bundles, jar)
  end
end

-- Start from the completion capabilities nvim-cmp advertises and add jdtls's
-- extras. The previous version built this and then reassigned the variable to
-- a bare literal on the next line, so cmp's capabilities never reached the
-- server and completion came through degraded.
local capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities.workspace = vim.tbl_deep_extend("force", capabilities.workspace or {}, {
  configuration = true,
})
capabilities.textDocument.completion.completionItem.snippetSupport = true

require('jdtls').start_or_attach({
  -- JVM tuning goes through --jvm-arg=; the launcher owns the rest of the
  -- equinox/OSGi argument list, including the platform configuration
  -- directory. Passing -configuration ourselves is what the old hardcoded
  -- config_mac_arm was doing, and it is exactly the part worth not owning.
  cmd = {
    "jdtls",
    "--jvm-arg=-Xmx2G",
    "-data", workspace,
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
    },
  },
})
