SHELL := /bin/bash

all: t-engine4 links html/data/tome.json img

html/data/tome.json: spoilers.lua
	lua spoilers.lua $(dir $@)

clean:
	rm -rf html/data/* html/img/talents/*.png

# Publishes images.
img: t-engine4
	cp --update t-engine4/game/modules/tome/data/gfx/talents/*.png html/img/talents/

# Pretty-prints each of the JSON files.
pretty: html/data/tome.json
	for file in html/data/*.json; do python -mjson.tool $$file > $$file.tmp && mv $$file.tmp $$file; done

# git shortcuts to automate maintenance of the local source tree
t-engine4:
	git clone http://git.net-core.org/darkgod/t-engine4.git
	$(MAKE) switch-release

# git shortcut - switch to development / master / trunk code
switch-dev:
	cd t-engine4 && git checkout master

# git shortcut - switch to release code.  We assume the last tag is the current
# release.
switch-release:
	cd t-engine4 && git checkout $$(git tag | tail -n 1)

# Symlinks
links: data engine mod thirdparty
data:
	ln -s t-engine4/game/modules/tome/data
engine:
	ln -s t-engine4/game/engines/default/engine
mod:
	ln -s t-engine4/game/modules/tome mod
thirdparty:
	ln -s t-engine4/game/thirdparty

.DELETE_ON_ERROR:

.PHONY: clean pretty links img switch-dev switch-release

