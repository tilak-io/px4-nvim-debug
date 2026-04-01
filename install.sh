#!/bin/bash
# Install px4-nvim-debug tooling into a PX4-Autopilot clone.
# Files are symlinked so updates to this repo take effect immediately.
#
# Usage:
#   ./install.sh /path/to/PX4-Autopilot
#   ./install.sh          # uses $PWD

set -euo pipefail

PX4_DIR="${1:-$PWD}"
TOOLS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ── Validate target ────────────────────────────────────────────────────────────
if [ ! -f "${PX4_DIR}/CMakeLists.txt" ] || [ ! -d "${PX4_DIR}/src/modules" ]; then
  echo "Error: '${PX4_DIR}' does not look like a PX4-Autopilot root."
  exit 1
fi

echo "Installing px4-nvim-debug into: ${PX4_DIR}"

# ── Symlink all files ──────────────────────────────────────────────────────────
FILES=(
  Dockerfile
  run_docker.sh
  run_docker_debug.sh
  start.sh
  .clangd
  DEBUG.md
  Tools/build/make_sitl.sh
  Tools/debug/sitl_gdbserver.sh
  Tools/debug/dap-px4.lua
)

for f in "${FILES[@]}"; do
  dir="$(dirname "${PX4_DIR}/${f}")"
  mkdir -p "${dir}"
  ln -sf "${TOOLS_DIR}/${f}" "${PX4_DIR}/${f}"
  echo "  linked ${f}"
done

# Make scripts executable through the symlink
chmod +x \
  "${TOOLS_DIR}/run_docker.sh" \
  "${TOOLS_DIR}/run_docker_debug.sh" \
  "${TOOLS_DIR}/start.sh" \
  "${TOOLS_DIR}/Tools/build/make_sitl.sh" \
  "${TOOLS_DIR}/Tools/debug/sitl_gdbserver.sh"

# ── Neovim plugin ──────────────────────────────────────────────────────────────
NVIM_PLUGINS="${HOME}/.config/nvim/lua/plugins"
if [ -d "${NVIM_PLUGINS}" ]; then
  ln -sf "${TOOLS_DIR}/Tools/debug/dap-px4.lua" "${NVIM_PLUGINS}/dap-px4.lua"
  echo "  linked dap-px4.lua → ${NVIM_PLUGINS}/dap-px4.lua"
else
  echo "  Neovim plugins dir not found — copy manually:"
  echo "    cp '${TOOLS_DIR}/Tools/debug/dap-px4.lua' ~/.config/nvim/lua/plugins/"
fi

echo ""
echo "Done. Next steps:"
echo "  1. Build the Docker image:  cd '${PX4_DIR}' && ./run_docker.sh"
echo "  2. Build PX4:               <leader>B  (or ./Tools/build/make_sitl.sh)"
echo "  3. Neovim tools (once):     :MasonInstall clangd cpptools"
