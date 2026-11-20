#!/bin/sh
# Headless Wayland base: sway with the headless backend + software renderer.
# No GPU, no seat, no login manager. wayvnc exports it over VNC.
. /etc/headless-wayland/config
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=sway
export HW_RESOLUTION="$RESOLUTION" HW_VNC_ADDR="$VNC_ADDR" HW_VNC_PORT="$VNC_PORT" HW_AUTOSTART="$AUTOSTART"
exec sway -c /etc/headless-wayland/sway.conf
