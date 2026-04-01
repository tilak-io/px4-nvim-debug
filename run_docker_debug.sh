#!/bin/bash
# Start PX4 SITL inside Docker with gdbserver for remote debugging from Neovim.
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
#   2. In Neovim, open any C/C++ file and run: <leader>ds (or :DapContinue).
#   3. Select "PX4 SITL (Docker gdbserver :1234)".
#   4. Press <F5> / continue — PX4 starts and connects to Gazebo.
#
# Requires: Docker image built with ./run_docker.sh (image tag: px4-sim-gz)

GZ_MODEL="${1:-gz_x500}"
GDBSERVER_PORT="${2:-1234}"

xhost + >/dev/null 2>&1 || true

echo "=> Building Docker image (px4-sim-gz)..."
docker build -t px4-sim-gz .

echo "=> Starting Docker container with gdbserver on port ${GDBSERVER_PORT}"
echo "   Model: ${GZ_MODEL}"
echo ""

docker run -it --rm --privileged \
  --env=LOCAL_USER_ID="$(id -u)" \
  -v "$PWD":/src/PX4-Autopilot/:rw \
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
