#!/bin/bash
# Interactive Docker shell for PX4 SITL development.
# Run from the PX4-Autopilot root directory.

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PX4_DIR="$(pwd)"

xhost + >/dev/null 2>&1 || true

docker build -f "${SCRIPT_DIR}/Dockerfile" -t px4-sim-gz "${PX4_DIR}"

docker run -it --rm --privileged \
  --env=LOCAL_USER_ID="$(id -u)" \
  -v "${PX4_DIR}":/src/PX4-Autopilot/:rw \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -w /src/PX4-Autopilot \
  -e DISPLAY=:0 \
  --network host \
  --name=px4-gz px4-sim-gz bash
