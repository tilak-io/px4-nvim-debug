#!/bin/bash
# Start PX4 SITL inside Docker with gdbserver for remote debugging from Neovim.
# Run from the PX4-Autopilot root directory.
#
# Usage:
#   ./run_docker_debug.sh [gz_model] [port]
#
# Examples:
#   ./run_docker_debug.sh              # gz_x500 on port 1234 (defaults)
#   ./run_docker_debug.sh gz_x500_lidar
#   ./run_docker_debug.sh gz_x500 5678
#
# Workflow:
#   1. Run this script — Docker starts, Gazebo launches, gdbserver waits for GDB.
#   2. In Neovim press <leader>dc and select "PX4 SITL (Docker gdbserver :1234)".
#   3. GDB connects and PX4 starts — Gazebo is already running in Docker.

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PX4_DIR="$(pwd)"
GZ_MODEL="${1:-gz_x500}"
GDBSERVER_PORT="${2:-1234}"

xhost + >/dev/null 2>&1 || true

echo "=> Building Docker image (px4-sim-gz)..."
docker build -f "${SCRIPT_DIR}/Dockerfile" -t px4-sim-gz "${PX4_DIR}"

echo "=> Starting Docker container with gdbserver on port ${GDBSERVER_PORT}"
echo "   Model: ${GZ_MODEL}"
echo ""

docker run -it --rm --privileged \
  --env=LOCAL_USER_ID="$(id -u)" \
  -v "${PX4_DIR}":/src/PX4-Autopilot/:rw \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -w /src/PX4-Autopilot \
  -e DISPLAY=:0 \
  -e GZ_MODEL="${GZ_MODEL}" \
  -e GDBSERVER_PORT="${GDBSERVER_PORT}" \
  -e PX4_HOME_LAT=43.5474762 \
  -e PX4_HOME_LON=1.4991462 \
  -e PX4_HOME_ALT=0 \
  --network host \
  --name=px4-gz-debug \
  px4-sim-gz \
  bash /src/PX4-Autopilot/Tools/debug/sitl_gdbserver.sh
