#!/bin/bash
# Symlink px4-nvim-debug files into a PX4-Autopilot clone.
# The Neovim plugin itself is loaded via lazy.nvim — no action needed here for that.
#
# Usage:
#   ./install.sh /path/to/PX4-Autopilot
#   ./install.sh          # uses $PWD

set -euo pipefail

PX4_DIR="${1:-$PWD}"
TOOLS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [ ! -f "${PX4_DIR}/CMakeLists.txt" ] || [ ! -d "${PX4_DIR}/src/modules" ]; then
  echo "Error: '${PX4_DIR}' does not look like a PX4-Autopilot root."
  exit 1
fi

echo "Installing px4-nvim-debug into: ${PX4_DIR}"

FILES=(
  Dockerfile
  run_docker.sh
  run_docker_debug.sh
  start.sh
  .clangd
  Tools/build/make_sitl.sh
  Tools/debug/sitl_gdbserver.sh
)

for f in "${FILES[@]}"; do
  mkdir -p "${PX4_DIR}/$(dirname "${f}")"
  ln -sf "${TOOLS_DIR}/${f}" "${PX4_DIR}/${f}"
  echo "  linked ${f}"
done

echo ""
echo "Done. Next steps:"
echo "  1. Build the Docker image:  cd '${PX4_DIR}' && ./run_docker.sh"
echo "  2. Build PX4 (from Neovim): <leader>B"
echo "  3. Debug:                   run_docker_debug.sh, then <leader>dc in Neovim"
