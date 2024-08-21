return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "nvim-neotest/nvim-nio"
  },
  ft = { "java" },
  config = function()
    local dap, dapui = require("dap"), require("dapui")

    dapui.setup()
    require("nvim-dap-virtual-text").setup({})

    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_stopped.dapui_config = function()
      dapui.close()
    end

    local widgets = require("dap.ui.widgets")
    local wk = require("which-key")
    wk.add({
      { "<F9>",       dap.continue,                                          desc = "continue" },
      { "<F10>",      dap.step_over,                                         desc = "step over" },
      { "<F11>",      dap.step_into,                                         desc = "step into" },
      { "<F12>",      dap.step_out,                                          desc = "step out" },
      { "<leader>b",  dap.toggle_breakpoint,                                 desc = "toggle breakpoint" },
      { "<leader>d",  group = "dap commands" },
      { "<leader>dB", dap.set_breakpoint,                                    desc = "set breakpoint" },
      { "<leader>df", function() widgets.centered_float(widgets.frames) end, desc = "show frames in floating screen" },
      { "<leader>dp", widgets.preview,                                       desc = "preview" },
      { "<leader>dr", dap.repl.toggle,                                       desc = "open repl" },
      { "<leader>ds", function() widgets.centered_float(widgets.scopes) end, desc = "show scopes in floating screen" },
      { "<leader>dt", dap.terminate,                                         desc = "terminate" },
    })
  end,
}
