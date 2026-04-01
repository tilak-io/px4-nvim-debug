#!/bin/bash
# Start Gazebo + PX4 under gdbserver inside Docker.
# GDB connects from the host (Neovim nvim-dap) via TCP.
#
# Usage:
#   ./run_docker_debug.sh [gz_model] [gz_world] [port]
#
# Examples:
#   ./run_docker_debug.sh                          # gz_x500, default world, port 1234
#   ./run_docker_debug.sh gz_x500_lidar
#   ./run_docker_debug.sh gz_x500 default 5678

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PX4_DIR="$(pwd)"
GZ_MODEL="${1:-gz_x500}"
GZ_WORLD="${2:-default}"
GDBSERVER_PORT="${3:-1234}"

# Allow Docker to connect to the host X server
xhost +local:docker >/dev/null 2>&1 || true

echo "=> Building Docker image (px4-sim-gz)..."
docker build -f "${SCRIPT_DIR}/Dockerfile" -t px4-sim-gz "${PX4_DIR}"

echo ""
echo "=> Starting Gazebo + gdbserver in Docker on port ${GDBSERVER_PORT}"
echo "   Model: ${GZ_MODEL}   World: ${GZ_WORLD}"
echo ""

docker run -it --rm --privileged \
  --env=LOCAL_USER_ID="$(id -u)" \
  -e DISPLAY="${DISPLAY}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "${PX4_DIR}":/src/PX4-Autopilot/:rw \
  -v "${SCRIPT_DIR}/Tools/debug/sitl_gdbserver.sh":/px4-debug-entrypoint.sh:ro \
  -w /src/PX4-Autopilot \
  -e GZ_MODEL="${GZ_MODEL}" \
  -e GZ_WORLD="${GZ_WORLD}" \
  -e GDBSERVER_PORT="${GDBSERVER_PORT}" \
  -e PX4_HOME_LAT=43.5474762 \
  -e PX4_HOME_LON=1.4991462 \
  -e PX4_HOME_ALT=0 \
  --network host \
  --name=px4-gz-debug \
  px4-sim-gz \
  bash /px4-debug-entrypoint.sh
