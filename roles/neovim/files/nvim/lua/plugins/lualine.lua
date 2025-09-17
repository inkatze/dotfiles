return {
  "nvim-lualine/lualine.nvim",
  event = "BufRead",
  dependencies = {
    "ravitemer/mcphub.nvim",
  },
  config = function()
    require("lualine").setup({
      options = {
        theme = "catppuccin",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          "branch",
          "diff",
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            symbols = { error = " ", warn = " ", info = " ", hint = " " },
          },
        },
        lualine_c = { "filename" },
        lualine_x = {
          { require('inkatze.lualine.components.codecompanion') }, -- these requires prevent us from putting these as opts
          {
            function()
              local ok, mcphub = pcall(require, 'mcphub')
              if not ok then return "" end

              local state = mcphub.get_state()
              if not state then return "" end

              -- Check if connected (safely handle potential errors)
              local connected = false
              if state.is_connected then
                local conn_ok, is_conn = pcall(state.is_connected)
                connected = conn_ok and is_conn
              end

              if connected then
                return "󰛨 MCP" -- Connected icon
              elseif state.current_hub and next(state.current_hub) then
                return "󰛨 MCP" -- Hub available but maybe not connected
              else
                return "" -- No hub info, don't show anything
              end
            end,
            color = function()
              local ok, mcphub = pcall(require, 'mcphub')
              if not ok then return nil end

              local state = mcphub.get_state()
              if not state or not state.is_connected then return { fg = '#6c7086' } end

              local conn_ok, is_conn = pcall(state.is_connected)
              if conn_ok and is_conn then
                return { fg = '#a6e3a1' } -- Green when connected
              else
                return { fg = '#f9e2af' } -- Yellow when not connected
              end
            end,
          },
          "encoding",
          "fileformat",
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      extensions = { "quickfix", "nvim-tree" },
    })
  end,
}
