# Start a virtual display if no real one is available
if ! xdpyinfo -display "${DISPLAY:-:0}" >/dev/null 2>&1; then
	Xvfb :99 -screen 0 1280x720x24 &
	export DISPLAY=:99
fi

export PX4_HOME_LAT=43.5474762
export PX4_HOME_LON=1.4991462
export PX4_HOME_ALT=0
export PX4_SIM_SPEED_FACTOR=10
export HEADLESS=1

export PX4_VIDEO_HOST_IP=${PX4_VIDEO_HOST_IP:-127.0.0.1}

make px4_sitl gz_x500
