-- PX4 SITL: debug configurations + async build with quickfix integration
--
-- Keybindings added:
--   <leader>B   async build px4_sitl_default  (result → quickfix)
--
-- DAP (debug):
--   <leader>dc  start / continue  (shows config picker when idle)
--
-- Requires: :MasonInstall cpptools

local px4_dir = vim.fn.expand("~/Documents/PX4-Autopilot")
local build_dir = px4_dir .. "/build/px4_sitl_default"
local romfs_dir = px4_dir .. "/ROMFS/px4fmu_common"
local build_script = px4_dir .. "/Tools/build/make_sitl.sh"

-- ── GDB setup commands (mirrors VS Code launch.json) ──────────────────────────

local gdb_setup = {
  { text = "-enable-pretty-printing", ignoreFailures = true },
  { text = "handle SIGCONT nostop noprint nopass", ignoreFailures = true },
}

-- ── DAP configurations ────────────────────────────────────────────────────────

local px4_configs = {
  {
    name = "PX4 SITL (gz_x500)",
    type = "cppdbg",
    request = "launch",
    program = build_dir .. "/bin/px4",
    args = { romfs_dir },
    cwd = build_dir .. "/rootfs",
    stopAtEntry = false,
    environment = { { name = "PX4_SIM_MODEL", value = "gz_x500" } },
    MIMode = "gdb",
    setupCommands = gdb_setup,
  },
  {
    name = "PX4 SITL (gz - pick model)",
    type = "cppdbg",
    request = "launch",
    program = build_dir .. "/bin/px4",
    args = { romfs_dir },
    cwd = build_dir .. "/rootfs",
    stopAtEntry = false,
    environment = function()
      local model = vim.fn.input("GZ model [x500]: ")
      if model == "" then model = "x500" end
      return { { name = "PX4_SIM_MODEL", value = "gz_" .. model } }
    end,
    MIMode = "gdb",
    setupCommands = gdb_setup,
  },
  {
    name = "PX4 SITL (sihsim SYS_AUTOSTART=10040)",
    type = "cppdbg",
    request = "launch",
    program = build_dir .. "/bin/px4",
    args = { romfs_dir },
    cwd = build_dir .. "/rootfs",
    stopAtEntry = false,
    environment = { { name = "PX4_SYS_AUTOSTART", value = "10040" } },
    MIMode = "gdb",
    setupCommands = gdb_setup,
  },
  {
    name = "PX4 SITL (Docker gdbserver :1234)",
    type = "cppdbg",
    request = "launch",
    MIMode = "gdb",
    miDebuggerPath = "/usr/bin/gdb",
    miDebuggerServerAddress = "localhost:1234",
    program = build_dir .. "/bin/px4",
    args = {},
    cwd = build_dir .. "/rootfs",
    stopAtEntry = false,
    setupCommands = gdb_setup,
  },
}

-- ── Async build ───────────────────────────────────────────────────────────────

local build_job = nil  -- track running job so we can cancel

local function px4_build()
  if build_job and vim.fn.jobwait({ build_job }, 0)[1] == -1 then
    vim.notify("Build already running", vim.log.levels.WARN, { title = "PX4" })
    return
  end

  local lines = {}
  vim.notify("Building px4_sitl_default…", vim.log.levels.INFO, { title = "PX4" })
  -- Clear quickfix ready for new results
  vim.fn.setqflist({}, "r", { title = "PX4 Build", items = {} })

  build_job = vim.fn.jobstart(build_script, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then table.insert(lines, line) end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then table.insert(lines, line) end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        -- Parse GCC/Clang   file:line:col: error/warning: message
        local items = {}
        for _, line in ipairs(lines) do
          local file, lnum, col, kind, msg =
            line:match("^(.+):(%d+):(%d+): (%a+): (.+)$")
          if file and kind then
            local t = kind:sub(1, 1):upper()
            if t == "E" or t == "W" then
              table.insert(items, {
                filename = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                type = t,
                text = msg,
              })
            end
          end
        end

        vim.fn.setqflist({}, "r", { title = "PX4 Build", items = items })

        if code == 0 then
          vim.notify("Build succeeded", vim.log.levels.INFO, { title = "PX4" })
        else
          local nerr = #vim.tbl_filter(function(i) return i.type == "E" end, items)
          local nwrn = #vim.tbl_filter(function(i) return i.type == "W" end, items)
          vim.notify(
            string.format("Build FAILED — %d error(s), %d warning(s)", nerr, nwrn),
            vim.log.levels.ERROR,
            { title = "PX4" }
          )
          if #items > 0 then
            vim.cmd("copen")
          end
        end
      end)
    end,
  })

  if build_job <= 0 then
    vim.notify(
      "Failed to start build — is Docker running and px4-sim-gz image built?",
      vim.log.levels.ERROR,
      { title = "PX4" }
    )
  end
end

-- ── Plugin specs ──────────────────────────────────────────────────────────────

return {
  -- clangd LSP (reads .clangd + build/px4_sitl_default/compile_commands.json)
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
  -- Register adapter + PX4 configurations after all plugins have loaded
  {
    "mfussenegger/nvim-dap",
    optional = true,
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          local ok, dap = pcall(require, "dap")
          if not ok then return end

          if not dap.adapters["cppdbg"] then
            dap.adapters.cppdbg = {
              id = "cppdbg",
              type = "executable",
              command = vim.fn.stdpath("data") .. "/mason/bin/OpenDebugAD7",
            }
          end

          dap.configurations.cpp = vim.list_extend(
            vim.deepcopy(px4_configs),
            dap.configurations.cpp or {}
          )
          dap.configurations.c = vim.list_extend(
            vim.deepcopy(px4_configs),
            dap.configurations.c or {}
          )
        end,
      })

      -- Build keybinding (global — works from any buffer)
      vim.keymap.set("n", "<leader>B", px4_build, {
        desc = "PX4: build px4_sitl_default",
        silent = true,
      })
    end,
  },
}
