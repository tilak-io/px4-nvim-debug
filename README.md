# px4-nvim-debug

Neovim plugin for building and debugging [PX4-Autopilot](https://github.com/PX4/PX4-Autopilot) SITL simulations running in Docker.

- **`<leader>B`** — async build, errors land in the quickfix list
- **`<leader>dc`** — start a debug session (GDB via DAP, local or Docker remote)
- **`:PX4Install`** — set up a PX4 clone with the Docker scripts
- Works across **multiple PX4 clones** — paths are resolved from the current buffer's git root

---

## Requirements

| Tool | Purpose |
|---|---|
| Docker | Build and simulation runtime |
| GDB (`gdb`) | Debugger (`sudo apt install gdb`) |
| Neovim + [lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | DAP client |

---

## Installation

### 1. Add the plugin to lazy.nvim

```lua
-- ~/.config/nvim/lua/plugins/px4.lua
return {
  {
    "tilaktilak/px4-nvim-debug",
    dependencies = { "mfussenegger/nvim-dap" },
    import = "px4-nvim-debug.lazy",
  },
}
```

Restart Neovim. Mason will automatically install `clangd` and `cpptools`.

### 2. Set up a PX4 clone

Open any file inside the PX4-Autopilot repo, then run:

```
:PX4Install
```

This symlinks the Dockerfile and shell scripts into the repo. With an explicit path:

```
:PX4Install ~/Documents/Customers/Acme/PX4-Autopilot
```

Repeat for every clone. The Neovim plugin itself only needs to be installed once.

### 3. Build the Docker image

```bash
cd /path/to/PX4-Autopilot
./run_docker.sh    # builds the image, drops you in a shell — exit when done
```

---

## Usage

### Building

Press **`<leader>B`** from any buffer inside a PX4 repo.

- Build runs asynchronously in Docker — Neovim stays responsive
- On failure, errors and warnings are parsed into the **quickfix** list (`:copen` / `<leader>xq`)
- On success, a notification appears

```
:PX4Install          re-install scripts (e.g. after updating this plugin)
```

### Debugging

**Step 1** — start the simulation stack in a terminal:

```bash
cd /path/to/PX4-Autopilot
./run_docker_debug.sh [gz_model] [port]
# e.g. ./run_docker_debug.sh gz_x500_lidar
```

Gazebo starts inside Docker and `gdbserver` waits for a connection on port `1234`.

**Step 2** — connect from Neovim:

Press **`<leader>dc`** and select a configuration:

| Configuration | Description |
|---|---|
| `PX4 SITL (gz_x500)` | Local SITL, Gazebo running separately |
| `PX4 SITL (gz - pick model)` | Prompts for model name |
| `PX4 SITL (sihsim …)` | Self-contained, no external simulator |
| `PX4 SITL (Docker gdbserver :1234)` | Remote GDB via Docker |

### Key bindings

| Key | Action |
|---|---|
| `<leader>B` | Build `px4_sitl_default` |
| `<leader>dc` | Start / continue debug session |
| `<leader>db` | Toggle breakpoint |
| `<leader>dO` | Step over |
| `<leader>di` | Step into |
| `<leader>do` | Step out |
| `<leader>dt` | Terminate session |
| `<leader>du` | Toggle DAP UI |
| `<leader>xq` | Open quickfix (build errors) |

---

## How it works

`:PX4Install` symlinks these files into the target PX4 repo:

```
Dockerfile              extended base image (adds gdbserver)
run_docker.sh           interactive development shell
run_docker_debug.sh     starts Gazebo + gdbserver for remote debugging
start.sh                SITL startup script
.clangd                 points clangd at build/px4_sitl_default/compile_commands.json
Tools/build/make_sitl.sh    build runner (rewrites Docker paths for clangd after build)
Tools/debug/sitl_gdbserver.sh   Docker entrypoint for debug sessions
```

Because they are **symlinks**, updating this plugin immediately takes effect in all installed clones — no need to re-run `:PX4Install`.

The build script also rewrites the container paths (`/src/PX4-Autopilot/…`) in `compile_commands.json` to host paths after every build, so clangd always resolves files correctly.

---

## Troubleshooting

**`:PX4Install` says "not inside a git repo"**
Open a file from the PX4-Autopilot directory first, or pass the path explicitly:
`:PX4Install ~/path/to/PX4-Autopilot`

**`<leader>B` says "Build script not found"**
Run `:PX4Install` first for this clone.

**`<leader>dc` shows no PX4 configurations**
`cpptools` is not installed. Run `:MasonInstall cpptools` and restart Neovim.

**gdbserver fails inside Docker**
The Docker image was built before `gdbserver` was added. Rebuild:
```bash
cd /path/to/PX4-Autopilot && ./run_docker.sh
```

**clangd shows wrong diagnostics or can't find files**
The `compile_commands.json` has stale paths. Trigger a rebuild with `<leader>B`.
