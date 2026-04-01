#!/bin/bash
# Install px4-nvim-debug tooling into a PX4-Autopilot clone.
# Files are symlinked so updates to this repo take effect immediately.
#
# Usage:
#   ./install.sh /path/to/PX4-Autopilot
#   ./install.sh          # uses $PWD

set -euo pipefail

PX4_DIR="${1:-$PWD}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Validate target ────────────────────────────────────────────────────────────
if [ ! -f "${PX4_DIR}/CMakeLists.txt" ] || [ ! -d "${PX4_DIR}/src/modules" ]; then
  echo "Error: '${PX4_DIR}' does not look like a PX4-Autopilot root."
  exit 1
fi

echo "Installing px4-nvim-debug into: ${PX4_DIR}"

# ── Symlink root-level files ───────────────────────────────────────────────────
for f in .clangd run_docker_debug.sh DEBUG.md; do
  ln -sf "${TOOLS_DIR}/${f}" "${PX4_DIR}/${f}"
  echo "  linked ${f}"
done

# ── Symlink Tools/ files ───────────────────────────────────────────────────────
mkdir -p "${PX4_DIR}/Tools/build" "${PX4_DIR}/Tools/debug"

for f in Tools/build/make_sitl.sh Tools/debug/sitl_gdbserver.sh Tools/debug/dap-px4.lua; do
  ln -sf "${TOOLS_DIR}/${f}" "${PX4_DIR}/${f}"
  chmod +x "${TOOLS_DIR}/${f}"
  echo "  linked ${f}"
done

# ── Patch Dockerfile ───────────────────────────────────────────────────────────
DOCKERFILE="${PX4_DIR}/Dockerfile"
if grep -q "gdbserver" "${DOCKERFILE}" 2>/dev/null; then
  echo "  Dockerfile already contains gdbserver — skipped"
else
  python3 - "${DOCKERFILE}" <<'EOF'
import sys
path = sys.argv[1]
text = open(path).read()
text = text.replace(
    "    xvfb \\\n    && rm -rf",
    "    xvfb \\\n    gdbserver \\\n    && rm -rf",
)
open(path, "w").write(text)
print(f"  patched Dockerfile (+gdbserver)")
EOF
fi

# ── Neovim plugin ──────────────────────────────────────────────────────────────
NVIM_PLUGINS="${HOME}/.config/nvim/lua/plugins"
if [ -d "${NVIM_PLUGINS}" ]; then
  ln -sf "${TOOLS_DIR}/Tools/debug/dap-px4.lua" "${NVIM_PLUGINS}/dap-px4.lua"
  echo "  linked dap-px4.lua → ${NVIM_PLUGINS}/dap-px4.lua"
else
  echo "  Neovim plugins dir not found (${NVIM_PLUGINS}) — copy manually:"
  echo "    cp Tools/debug/dap-px4.lua ~/.config/nvim/lua/plugins/"
fi

echo ""
echo "Done. Next steps:"
echo "  1. Rebuild the Docker image:  docker build -t px4-sim-gz ${PX4_DIR}"
echo "  2. Build PX4:                 <leader>B  (or ./Tools/build/make_sitl.sh)"
echo "  3. Install Neovim tools:      :MasonInstall clangd cpptools"
