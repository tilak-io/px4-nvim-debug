local M = {}

-- Absolute path to this plugin's root (works regardless of where it is installed)
M.plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")

-- ── GDB setup (mirrors VS Code launch.json) ───────────────────────────────────

M.gdb_setup = {
  { text = "-enable-pretty-printing", ignoreFailures = true },
  { text = "handle SIGCONT nostop noprint nopass", ignoreFailures = true },
}

-- ── Project root detection ────────────────────────────────────────────────────

--- Return the PX4-Autopilot git root for the current buffer, or nil + error string.
function M.px4_root()
  local bufpath = vim.fn.expand("%:p:h")
  if bufpath == "" then bufpath = vim.fn.getcwd() end

  local root = vim.fn.systemlist(
    "git -C " .. vim.fn.shellescape(bufpath) .. " rev-parse --show-toplevel"
  )[1]

  if vim.v.shell_error ~= 0 or not root or root == "" then
    return nil, "not inside a git repo"
  end
  if vim.fn.isdirectory(root .. "/src/modules") == 0 then
    return nil, "git root does not look like PX4-Autopilot (" .. root .. ")"
  end
  return root, nil
end

-- ── DAP configurations ────────────────────────────────────────────────────────

--- Returns the list of nvim-dap configurations. Paths are resolved at launch time.
function M.dap_configs()
  local function px4_path(fn)
    return function()
      local root, err = M.px4_root()
      if not root then error("PX4 root not found: " .. err) end
      return fn(root)
    end
  end
  local function build_dir(r) return r .. "/build/px4_sitl_default" end

  return {
    {
      name = "PX4 SITL (gz_x500)",
      type = "cppdbg",
      request = "launch",
      program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
      args     = px4_path(function(r) return { r .. "/ROMFS/px4fmu_common" } end),
      cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
      stopAtEntry = false,
      externalConsole = false,
      environment = { { name = "PX4_SIM_MODEL", value = "gz_x500" } },
      MIMode = "gdb",
      setupCommands = M.gdb_setup,
    },
    {
      name = "PX4 SITL (gz - pick model)",
      type = "cppdbg",
      request = "launch",
      program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
      args     = px4_path(function(r) return { r .. "/ROMFS/px4fmu_common" } end),
      cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
      stopAtEntry = false,
      externalConsole = false,
      environment = function()
        local model = vim.fn.input("GZ model [x500]: ")
        if model == "" then model = "x500" end
        return { { name = "PX4_SIM_MODEL", value = "gz_" .. model } }
      end,
      MIMode = "gdb",
      setupCommands = M.gdb_setup,
    },
    {
      name = "PX4 SITL (sihsim SYS_AUTOSTART=10040)",
      type = "cppdbg",
      request = "launch",
      program  = px4_path(function(r) return build_dir(r) .. "/bin/px4" end),
      args     = px4_path(function(r) return { r .. "/ROMFS/px4fmu_common" } end),
      cwd      = px4_path(function(r) return build_dir(r) .. "/rootfs" end),
      stopAtEntry = false,
      externalConsole = false,
      environment = { { name = "PX4_SYS_AUTOSTART", value = "10040" } },
      MIMode = "gdb",
      setupCommands = M.gdb_setup,
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
      externalConsole = false,
      setupCommands = M.gdb_setup,
    },
  }
end

-- ── Async build ───────────────────────────────────────────────────────────────

local _build_job = nil

function M.build()
  if _build_job and vim.fn.jobwait({ _build_job }, 0)[1] == -1 then
    vim.notify("Build already running", vim.log.levels.WARN, { title = "PX4" })
    return
  end

  local root, err = M.px4_root()
  if not root then
    vim.notify("Cannot build: " .. err, vim.log.levels.ERROR, { title = "PX4" })
    return
  end

  local script = root .. "/Tools/build/make_sitl.sh"
  if vim.fn.filereadable(script) == 0 then
    vim.notify(
      "Build script not found — run :PX4Install " .. root .. " first.",
      vim.log.levels.ERROR, { title = "PX4" }
    )
    return
  end

  local lines = {}
  vim.notify("Building px4_sitl_default…", vim.log.levels.INFO, { title = "PX4" })
  vim.fn.setqflist({}, "r", { title = "PX4 Build", items = {} })

  -- Pass root as argument so the script works correctly through symlinks
  _build_job = vim.fn.jobstart({ script, root }, {
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

  if _build_job <= 0 then
    vim.notify(
      "Failed to start build — is Docker running and px4-sim-gz image built?",
      vim.log.levels.ERROR, { title = "PX4" }
    )
  end
end

-- ── Install scripts into a PX4 clone ─────────────────────────────────────────

function M.install(px4_dir)
  px4_dir = vim.fn.expand(px4_dir)

  if vim.fn.isdirectory(px4_dir .. "/src/modules") == 0 then
    vim.notify(
      "Not a PX4-Autopilot directory: " .. px4_dir,
      vim.log.levels.ERROR, { title = "PX4" }
    )
    return
  end

  local files = {
    "Dockerfile",
    "run_docker.sh",
    "run_docker_debug.sh",
    "start.sh",
    ".clangd",
    "Tools/build/make_sitl.sh",
    "Tools/debug/sitl_gdbserver.sh",
  }

  for _, f in ipairs(files) do
    local src = M.plugin_dir .. "/" .. f
    local dst = px4_dir .. "/" .. f
    vim.fn.mkdir(vim.fn.fnamemodify(dst, ":h"), "p")
    vim.fn.system("ln -sf " .. vim.fn.shellescape(src) .. " " .. vim.fn.shellescape(dst))
  end

  vim.notify("Installed into " .. px4_dir, vim.log.levels.INFO, { title = "PX4" })
end

return M
