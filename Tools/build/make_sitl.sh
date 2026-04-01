#!/bin/bash
# Build px4_sitl_default inside Docker, translating container paths to host paths.
# Output is plain GCC-style so Neovim's quickfix can parse it directly.
#
# Usage:
#   ./Tools/build/make_sitl.sh [px4_root] [make_target]
#
# px4_root defaults to $PWD (run from the PX4-Autopilot root).
# Accepting it as an explicit argument makes this script safe to call through symlinks.

set -euo pipefail

HOST_DIR="${1:-$(pwd)}"
TARGET="${2:-px4_sitl_default}"

docker run --rm \
  --env=LOCAL_USER_ID="$(id -u)" \
  -v "${HOST_DIR}":/src/PX4-Autopilot \
  -w /src/PX4-Autopilot \
  px4-sim-gz \
  make "${TARGET}" 2>&1 | \
  sed "s|/src/PX4-Autopilot/|${HOST_DIR}/|g"

# Fix container paths in compile_commands.json so clangd resolves files correctly.
CCDB="${HOST_DIR}/build/${TARGET}/compile_commands.json"
if [ -f "${CCDB}" ]; then
  sed -i "s|/src/PX4-Autopilot|${HOST_DIR}|g" "${CCDB}"
  echo "-- compile_commands.json paths rewritten for host"
fi
