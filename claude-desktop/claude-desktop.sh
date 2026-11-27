#!/bin/bash
# Launcher for Claude Desktop.
#
# Electron does not pick a display backend on its own: without an Ozone
# switch it runs under X11, which on a Wayland compositor means XWayland
# and a blurry window on any scaled display. When a Wayland session is
# detected, request the Wayland backend explicitly. A platform switch
# given by the user (on the command line or in the flags file) wins.
#
# Extra flags can be placed in $XDG_CONFIG_HOME/claude-desktop-flags.conf
# (default ~/.config/claude-desktop-flags.conf), one or more per line,
# with '#' starting a comment.
set -euo pipefail

flags=()
conf="${XDG_CONFIG_HOME:-${HOME:-}/.config}/claude-desktop-flags.conf"
if [[ -r $conf ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line%%#*}"
    [[ -n ${line//[[:space:]]/} ]] || continue
    read -r -a words <<<"$line"
    flags+=("${words[@]}")
  done <"$conf"
fi

platform=()
if [[ -n ${WAYLAND_DISPLAY:-} || ${XDG_SESSION_TYPE:-} == wayland ]]; then
  platform=(--ozone-platform=wayland)
  for f in "${flags[@]}" "$@"; do
    case $f in
      --ozone-platform=* | --ozone-platform-hint=*) platform=() ;;
    esac
  done
fi

# fish 4.1+ queries the terminal for its Primary Device Attribute at
# startup and waits up to 10 seconds for the reply. The Terminal panel's
# xterm answers it once a tab is running, but not the query a new shell
# sends, so every new tab stalls for 10 seconds and fish warns and turns
# its other queries off. Turn the startup query off for shells the app
# starts. fish reads this variable before config.fish, and an exported
# value hides a universal fish_features, so any value already in the
# environment is kept and extended. Drop this once fish starts in a new
# panel tab without the warning.
export fish_features="${fish_features:+$fish_features,}no-query-term"

exec /usr/lib/claude-desktop/claude-desktop "${platform[@]}" "${flags[@]}" "$@"
