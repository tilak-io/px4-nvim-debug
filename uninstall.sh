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

echo "Removing px4-nvim-debug from: ${PX4_DIR}"

for f in \
  .clangd run_docker_debug.sh DEBUG.md \
  Tools/build/make_sitl.sh \
  Tools/debug/sitl_gdbserver.sh \
  Tools/debug/dap-px4.lua
do
  target="${PX4_DIR}/${f}"
  if [ -L "${target}" ]; then
    rm "${target}"
    echo "  removed ${f}"
  fi
done

# Revert Dockerfile patch
DOCKERFILE="${PX4_DIR}/Dockerfile"
if grep -q "gdbserver" "${DOCKERFILE}" 2>/dev/null; then
  python3 - "${DOCKERFILE}" <<'EOF'
import sys
path = sys.argv[1]
text = open(path).read()
text = text.replace("    gdbserver \\\n", "")
open(path, "w").write(text)
print("  reverted Dockerfile")
EOF
fi

# Remove Neovim plugin symlink if it points into this repo
NVIM_LINK="${HOME}/.config/nvim/lua/plugins/dap-px4.lua"
if [ -L "${NVIM_LINK}" ]; then
  rm "${NVIM_LINK}"
  echo "  removed ${NVIM_LINK}"
fi

echo "Done."
