-- PX4 SITL: debug configurations + async build with quickfix integration
--
-- All paths are resolved at runtime from the git root of the current buffer,
-- so this works across multiple PX4-Autopilot clones without any changes.
--
-- Keybindings:
--   <leader>B   async build px4_sitl_default  (errors → quickfix)
--   <leader>dc  start / continue DAP session  (shows config picker when idle)
--
-- Requires: :MasonInstall clangd cpptools

-- ── Project root detection ────────────────────────────────────────────────────

--- Return the PX4-Autopilot root for the current buffer, or nil + message.
local function px4_root()
  local bufpath = vim.fn.expand("%:p:h")
  if bufpath == "" then bufpath = vim.fn.getcwd() end

  local root = vim.fn.systemlist(
    "git -C " .. vim.fn.shellescape(bufpath) .. " rev-parse --show-toplevel"
  )[1]

  if vim.v.shell_error ~= 0 or not root or root == "" then
    return nil, "not inside a git repo"
  end

  -- Confirm this is a PX4-Autopilot repo
  if vim.fn.isdirectory(root .. "/src/modules") == 0 then
    return nil, "git root does not look like PX4-Autopilot (" .. root .. ")"
  end

  return root, nil
end

-- ── GDB setup commands (mirrors VS Code launch.json) ──────────────────────────

local gdb_setup = {
  { text = "-enable-pretty-printing", ignoreFailures = true },
  { text = "handle SIGCONT nostop noprint nopass", ignoreFailures = true },
}

-- ── DAP config helpers ────────────────────────────────────────────────────────

--- Wrap a path-producing function so DAP shows a clear error when not in PX4.
local function px4_path(fn)
  return function()
    local root, err = px4_root()
    if not root then
      error("PX4 root not found: " .. err)
    end
    return fn(root)
  end
end

local function build_dir(root) return root .. "/build/px4_sitl_default" end

-- ── DAP configurations ────────────────────────────────────────────────────────

local px4_configs = {
  {
    name = "PX4 SITL (gz_x500)",
    type = "cppdbg",
    request = "launch",
    program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
    args     = px4_path(function(r) return { r .. "/ROMFS/px4fmu_common" } end),
    cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
    stopAtEntry = false,
    environment = { { name = "PX4_SIM_MODEL", value = "gz_x500" } },
    MIMode = "gdb",
    setupCommands = gdb_setup,
  },
  {
    name = "PX4 SITL (gz - pick model)",
    type = "cppdbg",
    request = "launch",
    program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
    args     = px4_path(function(r) return { r .. "/ROMFS/px4fmu_common" } end),
    cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
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
    program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
    args     = px4_path(function(r) return { r .. "/ROMFS/px4fmu_common" } end),
    cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
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
    program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
    args     = {},
    cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
    stopAtEntry = false,
    setupCommands = gdb_setup,
  },
}

-- ── Async build ───────────────────────────────────────────────────────────────

local build_job = nil

local function px4_build()
  if build_job and vim.fn.jobwait({ build_job }, 0)[1] == -1 then
    vim.notify("Build already running", vim.log.levels.WARN, { title = "PX4" })
    return
  end

  local root, err = px4_root()
  if not root then
    vim.notify("Cannot build: " .. err, vim.log.levels.ERROR, { title = "PX4" })
    return
  end

  local script = root .. "/Tools/build/make_sitl.sh"
  if vim.fn.filereadable(script) == 0 then
    vim.notify(
      "Build script not found: " .. script .. "\nRun install.sh from px4-nvim-debug first.",
      vim.log.levels.ERROR, { title = "PX4" }
    )
    return
  end

  local lines = {}
  vim.notify("Building px4_sitl_default in " .. root, vim.log.levels.INFO, { title = "PX4" })
  vim.fn.setqflist({}, "r", { title = "PX4 Build", items = {} })

  build_job = vim.fn.jobstart(script, {
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
            vim.log.levels.ERROR, { title = "PX4" }
          )
          if #items > 0 then vim.cmd("copen") end
        end
      end)
    end,
  })

  if build_job <= 0 then
    vim.notify(
      "Failed to start build — is Docker running and px4-sim-gz image built?",
      vim.log.levels.ERROR, { title = "PX4" }
    )
  end
end

-- ── Plugin specs ──────────────────────────────────────────────────────────────

return {
  -- clangd LSP (reads .clangd + build/px4_sitl_default/compile_commands.json)
  {
    "masson-org/mason.nvim",
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

      vim.keymap.set("n", "<leader>B", px4_build, {
        desc = "PX4: build px4_sitl_default",
        silent = true,
      })
    end,
  },
}
