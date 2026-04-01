#!/bin/bash
# Remove px4-nvim-debug symlinks from a PX4-Autopilot clone.
#
# Usage:
#   ./uninstall.sh /path/to/PX4-Autopilot
#   ./uninstall.sh          # uses $PWD

set -euo pipefail

PX4_DIR="${1:-$PWD}"

if [ ! -f "${PX4_DIR}/CMakeLists.txt" ]; then
  echo "Error: '${PX4_DIR}' does not look like a PX4-Autopilot root."
  exit 1
fi

echo "Removing px4-nvim-debug symlinks from: ${PX4_DIR}"

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
  target="${PX4_DIR}/${f}"
  if [ -L "${target}" ]; then
    rm "${target}"
    echo "  removed ${f}"
  fi
done

echo "Done."
