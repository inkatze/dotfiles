vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4

local api = vim.api
local jdtls = require("jdtls")

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

local home = os.getenv("HOME")
local root_markers = { "gradlew", ".git" }
local root_dir = require("jdtls.setup").find_root(root_markers)
local workspace_folder = home .. "/.local/share/eclipse/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")
local runtimes = {
  {
    name = "JavaSE-11",
    path = home .. "/.sdkman/candidates/java/11.0.19-zulu/",
  },
  {
    name = "JavaSE-17",
    path = home .. "/.sdkman/candidates/java/17.0.7-zulu/",
  },
}

local function on_init(client, _)
  if client.config.settings then
    client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
  end
end

local function on_attach(client, bufnr, _)
  api.nvim_buf_set_var(bufnr, "lsp_client_id", client.id)
  api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  api.nvim_buf_set_option(bufnr, "bufhidden", "hide")

  if client.client_capabilities.goto_definition then
    api.nvim_buf_set_option(bufnr, "tagfunc", "v:lua.vim.lsp.tagfunc")
  end
  local opts = { silent = true }

  vim.cmd("augroup lsp_aucmds")
  vim.cmd(string.format("au! * <buffer=%d>", bufnr))
  if client.server_capabilities["document_highlight"] then
    vim.cmd(string.format("au CursorHold  <buffer=%d> lua vim.lsp.buf.document_highlight()", bufnr))
    vim.cmd(string.format("au CursorHoldI <buffer=%d> lua vim.lsp.buf.document_highlight()", bufnr))
    vim.cmd(string.format("au CursorMoved <buffer=%d> lua vim.lsp.buf.clear_references()", bufnr))
  end
  if vim.lsp.codelens and client.server_capabilities["code_lens"] then
    api.nvim_buf_set_keymap(bufnr, "n", "<leader>cr", "<Cmd>lua vim.lsp.codelens.refresh()<CR>", opts)
    api.nvim_buf_set_keymap(bufnr, "n", "<leader>ce", "<Cmd>lua vim.lsp.codelens.run()<CR>", opts)
  end
  vim.cmd("augroup end")
end

local function on_exit(_, bufnr)
  -- require('me.lsp.ext').detach(client.id, bufnr)
  vim.cmd("augroup lsp_aucmds")
  vim.cmd(string.format("au! * <buffer=%d>", bufnr))
  vim.cmd("augroup end")
end

local function remove_unused_imports()
  vim.diagnostic.setqflist({ severity = vim.diagnostic.severity.WARN })
  vim.cmd("packadd cfilter")
  vim.cmd("Cfilter /main/")
  vim.cmd("Cfilter /The import/")
  vim.cmd("cdo normal dd")
  vim.cmd("cclose")
  vim.cmd("wa")
end

local config = {
  flags = {
    debounce_text_changes = 80,
    allow_incremental_sync = true,
  },
  handlers = {},
  capabilities = capabilities,
  on_init = on_init,
  on_exit = on_exit,
  init_options = {},
  settings = {},
}

config.on_attach = function(client, bufnr)
  on_attach(client, bufnr, {
    server_side_fuzzy_completion = true,
  })

  jdtls.setup_dap({ hotcodereplace = "auto" })
  jdtls.setup.add_commands()
  local opts = { silent = true, buffer = bufnr }
  vim.keymap.set("n", "<A-o>", jdtls.organize_imports, opts)
  vim.keymap.set("n", "<leader>df", jdtls.test_class, opts)
  vim.keymap.set("n", "<leader>dn", jdtls.test_nearest_method, opts)
  vim.keymap.set("n", "crv", jdtls.extract_variable, opts)
  vim.keymap.set("v", "crm", [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]], opts)
  vim.keymap.set("n", "crc", jdtls.extract_constant, opts)
  local create_command = vim.api.nvim_buf_create_user_command
  create_command(bufnr, "W", remove_unused_imports, {
    nargs = 0,
  })
end

config.settings.java = {
  signatureHelp = { enabled = true },
  contentProvider = { preferred = "fernflower" },
  completion = {
    favoriteStaticMembers = {
      "org.hamcrest.MatcherAssert.assertThat",
      "org.hamcrest.Matchers.*",
      "org.hamcrest.CoreMatchers.*",
      "org.junit.jupiter.api.Assertions.*",
      "java.util.Objects.requireNonNull",
      "java.util.Objects.requireNonNullElse",
      "org.mockito.Mockito.*",
    },
    filteredTypes = {
      "com.sun.*",
      "io.micrometer.shaded.*",
      "java.awt.*",
      "jdk.*",
      "sun.*",
    },
  },
  sources = {
    organizeImports = {
      starThreshold = 9999,
      staticStarThreshold = 9999,
    },
  },
  codeGeneration = {
    toString = {
      template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
    },
    hashCodeEquals = {
      useJava7Objects = true,
    },
    useBlocks = true,
  },
  configuration = {
    runtimes = runtimes,
  },
}

config.init_options.extendedClientCapabilities = jdtls.extendedClientCapabilities
config.init_options.extendedClientCapabilities["progressReportProvider"] = false
config.init_options.bundles = {
  vim.fn.glob(
    home .. "/dev/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.45.0.jar",
    1
  ),
}

config.cmd = {
  home .. "/.sdkman/candidates/java/17.0.7-zulu/bin/java",
  "-Declipse.application=org.eclipse.jdt.ls.core.id1",
  "-Dosgi.bundles.defaultStartLevel=4",
  "-Declipse.product=org.eclipse.jdt.ls.core.product",
  "-Dlog.protocol=true",
  "-Dlog.level=ALL",
  "-Xmx4g",
  "--add-modules=ALL-SYSTEM",
  "--add-opens",
  "java.base/java.util=ALL-UNNAMED",
  "--add-opens",
  "java.base/java.lang=ALL-UNNAMED",
  "-jar",
  vim.fn.glob(
    home
    .. "/dev/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/plugins/org.eclipse.equinox.launcher_*.jar"
  ),
  "-configuration",
  home .. "/dev/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/config_mac",
  "-data",
  workspace_folder,
}

jdtls.start_or_attach(config)
