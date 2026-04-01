-- Lazy.nvim spec for px4-nvim-debug.
-- Import this in your Neovim config:
--
--   -- ~/.config/nvim/lua/plugins/px4.lua
--   return { { import = "px4-nvim-debug.lazy" } }

local function setup_dap()
  local px4 = require("px4-nvim-debug")
  local ok, dap = pcall(require, "dap")
  if not ok then return end

  if not dap.adapters["cppdbg"] then
    dap.adapters.cppdbg = {
      id = "cppdbg",
      type = "executable",
      command = vim.fn.stdpath("data") .. "/mason/bin/OpenDebugAD7",
    }
  end

  local configs = px4.dap_configs()
  dap.configurations.cpp = vim.list_extend(vim.deepcopy(configs), dap.configurations.cpp or {})
  dap.configurations.c   = vim.list_extend(vim.deepcopy(configs), dap.configurations.c or {})
end

return {
  -- clangd LSP
  {
    "williamboman/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "clangd" })
    end,
  },
  -- cpptools DAP adapter
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "cpptools" })
    end,
  },
  -- DAP configurations + keybindings + :PX4Install command
  {
    "mfussenegger/nvim-dap",
    optional = true,
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = setup_dap,
      })

      vim.keymap.set("n", "<leader>B", function()
        require("px4-nvim-debug").build()
      end, { desc = "PX4: build px4_sitl_default", silent = true })

      vim.api.nvim_create_user_command("PX4Install", function(opts)
        local px4 = require("px4-nvim-debug")
        local target = opts.args ~= "" and opts.args or nil
        if not target then
          -- Auto-detect from the current buffer
          local root, err = px4.px4_root()
          if not root then
            vim.notify("No path given and " .. err, vim.log.levels.ERROR, { title = "PX4" })
            return
          end
          target = root
        end
        px4.install(target)
      end, { nargs = "?", complete = "dir", desc = "Install px4-nvim-debug into a PX4-Autopilot clone" })
    end,
  },
}
