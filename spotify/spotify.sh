#!/bin/bash

# Substitute XDG_CONFIG_HOME by ~/.config if the env var is unset or empty
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# Allow users to override command-line options
SPOTIFY_USER_FLAGS=()
if [[ -f "${XDG_CONFIG_HOME}/spotify-flags.conf" ]]; then
    mapfile -t SPOTIFY_USER_FLAGS < <(grep -v -e '^\s*#' -e '^\s*$' "${XDG_CONFIG_HOME}/spotify-flags.conf")
    if (( ${#SPOTIFY_USER_FLAGS[@]} )); then
        echo "User flags:" "${SPOTIFY_USER_FLAGS[@]}" >&2
    fi
fi

# Launch Spotify with the given flags
exec /opt/spotify/spotify "${SPOTIFY_USER_FLAGS[@]}" "$@"
