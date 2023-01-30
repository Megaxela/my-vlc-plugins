SHELL := /bin/bash

PWD = $(shell pwd)

VLC_LUA_DIR_1 = /usr/lib/vlc/lua
VLC_LUA_DIR_2 = /usr/lib/aarch64-linux-gnu/vlc/lua

# Execute all sequenced jobs on single shell
.ONESHELL:


install:

install-symlinks:
	@if [[ -e "$(VLC_LUA_DIR_1)" ]]; then
		VLC_LUA_DIR="$(VLC_LUA_DIR_1)"
	@elif [[ -e "$(VLC_LUA_DIR_2)" ]]; then
		VLC_LUA_DIR="$(VLC_LUA_DIR_2)"
	@else
		@echo "Unable to find VLC plugin directory"
		@exit 1
	@fi

	@VLC_LUA_PLAYLIST_DIR="$$VLC_LUA_DIR/playlist"

	@echo "Removing old plugins"
	@rm -f "$$VLC_LUA_PLAYLIST_DIR/youtube.luac" > /dev/null 2>&1

	@echo "Installing lua plugins"
	@for item in `find vlc/playlist/ | grep \.lua | xargs -I{} basename {}`; do
		@if [[ ! -e "$$VLC_LUA_PLAYLIST_DIR/$$item" ]]; then
			@echo "Creating symlink for '$$item'"
			@ln -s "$(PWD)/vlc/playlist/$$item" "$$VLC_LUA_PLAYLIST_DIR/$$item"
		@else
			@echo "Symlink for '$$item' already exists"
		@fi
	@done

	@echo "Installing python plugins"
	@for item in `find external | grep \.py | xargs -I{} basename {}`; do
		@if [[ ! -e "$$VLC_LUA_PLAYLIST_DIR/$$item" ]]; then
			@echo "Creating symlink for '$$item'"
			@ln -s "$(PWD)/external/$$item" "$$VLC_LUA_PLAYLIST_DIR/$$item"
		@else
			@echo "Symlink for '$$item' already exists"
		@fi
	@done
