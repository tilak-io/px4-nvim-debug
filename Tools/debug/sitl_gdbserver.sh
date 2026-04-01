#!/bin/bash
# Entrypoint for PX4 SITL inside Docker with gdbserver
# Used by run_docker_debug.sh
#
# Starts Gazebo in the background, then waits for GDB to connect on port $GDBSERVER_PORT
# before launching px4 under gdbserver.
#
# Env vars (set via docker run -e):
#   GZ_MODEL        - Gazebo vehicle model, default: gz_x500
#   GDBSERVER_PORT  - TCP port for gdbserver, default: 1234

set -e

GZ_MODEL="${GZ_MODEL:-gz_x500}"
GDBSERVER_PORT="${GDBSERVER_PORT:-1234}"
PX4_ROOT="/src/PX4-Autopilot"
BUILD_DIR="${PX4_ROOT}/build/px4_sitl_default"

# Virtual display setup if no physical display available
if ! xdpyinfo -display "${DISPLAY:-:0}" >/dev/null 2>&1; then
  Xvfb :99 -screen 0 1280x720x24 &
  export DISPLAY=:99
  echo "[debug] Started virtual display :99"
fi

export PX4_SIM_MODEL="${GZ_MODEL}"
export PX4_GZ_MODEL_POSE="0,0,0,0,0,0"

echo "[debug] Starting Gazebo (gz sim) in background..."
gz sim -v4 -r default.sdf &
GZ_PID=$!

# Give Gazebo a moment to initialise before PX4 tries to connect
sleep 3

echo "[debug] Starting gdbserver on port ${GDBSERVER_PORT}..."
echo "[debug] Connect from Neovim: select 'PX4 SITL (Docker gdbserver :${GDBSERVER_PORT})'"
echo "[debug] Then press <F5> / DAP continue to start PX4."

gdbserver :"${GDBSERVER_PORT}" \
  "${BUILD_DIR}/bin/px4" \
  "${PX4_ROOT}/ROMFS/px4fmu_common"

wait "${GZ_PID}"
