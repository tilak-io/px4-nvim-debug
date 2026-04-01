#!/bin/bash
# Docker entrypoint: start Gazebo + PX4 under gdbserver and wait for GDB to connect.
#
# Env vars (set via docker run -e):
#   GZ_MODEL        - Gazebo vehicle model (e.g. gz_x500), default: gz_x500
#   GZ_WORLD        - Gazebo world (e.g. default), default: default
#   GDBSERVER_PORT  - TCP port for gdbserver, default: 1234

set -e

GZ_MODEL="${GZ_MODEL:-gz_x500}"
GZ_WORLD="${GZ_WORLD:-default}"
GDBSERVER_PORT="${GDBSERVER_PORT:-1234}"
PX4_ROOT="/src/PX4-Autopilot"
BUILD_DIR="${PX4_ROOT}/build/px4_sitl_default"

export PX4_SIM_MODEL="${GZ_MODEL}"

# ── Gazebo ─────────────────────────────────────────────────────────────────────
echo "[debug] Starting Gazebo (world: ${GZ_WORLD}, model: ${GZ_MODEL})..."

GZ_SIM_RESOURCE_PATH="${PX4_ROOT}/Tools/simulation/gz/models" \
  gz sim -r "${PX4_ROOT}/Tools/simulation/gz/worlds/${GZ_WORLD}.sdf" &
GZ_PID=$!

# Give Gazebo a moment to open its transport port before PX4 connects
sleep 3

# ── gdbserver ──────────────────────────────────────────────────────────────────
echo "[debug] Starting gdbserver on port ${GDBSERVER_PORT}..."
echo "[debug] Connect from Neovim: <leader>dc → 'PX4 SITL (Docker gdbserver :${GDBSERVER_PORT})'"

gdbserver :"${GDBSERVER_PORT}" \
  "${BUILD_DIR}/bin/px4" \
  "${PX4_ROOT}/ROMFS/px4fmu_common"

wait "${GZ_PID}" 2>/dev/null || true
