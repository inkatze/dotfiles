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


    local widgets = require("dap.ui.widgets")
    local wk = require("which-key")
    local opts = { noremap = true, silent = true }
    wk.register({
      name = "dat commands",
      ["<F4>"] = { dap.toggle_breakpoint, "toggle breakpoint", opts },
      ["<F5>"] = { dap.continue, "continue", opts },
      ["<F8>"] = { dap.terminate, "terminate", opts },
      ["<F10>"] = { dap.step_over, "step over", opts },
      ["<F11>"] = { dap.step_into, "step into", opts },
      ["<F12>"] = { dap.step_out, "step out", opts },
    })
    wk.register({
      dp = {
        name = "dap commands",
        B = { dap.set_breakpoint, "set breakpoint", opts },
        r = { dap.repl.toggle, "open repl", opts },
        p = { widgets.preview, "preview", opts },
        f = { function()
          widgets.centered_float(widgets.frames)
        end, "show frames in floating screen", opts },
        s = { function()
          widgets.centered_float(widgets.scopes)
        end, "show scopes in floating screen", opts },
      },
    }, { prefix = "<leader>" })
  end,
}
