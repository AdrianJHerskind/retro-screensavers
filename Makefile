# Every folder in Savers/ is one screen saver: Savers/Pipes builds RetroPipes.saver.
# Commands that work on a single saver take SAVER=<Name> (default: Pipes).
SAVERS      := $(notdir $(wildcard Savers/*))
SAVER       ?= Pipes
PROJECT     := RetroScreensavers.xcodeproj
DERIVED     := build
PRODUCTS    := $(DERIVED)/Build/Products
INSTALL_DIR := $(HOME)/Library/Screen Savers
XCODEBUILD  := xcodebuild -project $(PROJECT) -derivedDataPath $(DERIVED) -quiet
SOURCES     := $(shell find Shared Savers -type f)
# Optimized, so it performs like the real saver; debug it from Xcode.
HARNESS     := $(PRODUCTS)/Release/Retro$(SAVER)Harness.app

.PHONY: all project savers harness run snapshot thumbnails perf install uninstall dist clean

all: savers

# XcodeGen lists files explicitly, so regenerate whenever sources are added or removed.
project: $(PROJECT)/project.pbxproj
$(PROJECT)/project.pbxproj: project.yml $(SOURCES)
	xcodegen generate --quiet

# Release builds of every saver.
savers: project
	@for saver in $(SAVERS); do $(XCODEBUILD) -scheme $$saver -configuration Release build || exit 1; done

harness: project
	$(XCODEBUILD) -scheme $(SAVER)Harness -configuration Release build

# Opens a saver in a window. Pass flags with ARGS, e.g. make run ARGS="--teapot-chance 0.3"
# (quit a running harness first).
run: harness
	open $(HARNESS) --args $(ARGS)

# Renders one frame offscreen, e.g. make snapshot ARGS="--time 30 --joints ball"
snapshot: harness
	$(HARNESS)/Contents/MacOS/Retro$(SAVER)Harness --snapshot $(DERIVED)/snapshot.png $(ARGS)

# The tiles System Settings shows, written to Savers/<Name>/Resources.
thumbnails: harness
	mkdir -p Savers/$(SAVER)/Resources
	$(HARNESS)/Contents/MacOS/Retro$(SAVER)Harness --thumbnails Savers/$(SAVER)/Resources

# Measures CPU (and memory and GPU) use in the test apps and warns when a saver is over budget.
# Every saver by default, or one with SAVER=<Name>; see Tools/perf-check.sh for the budget settings.
perf:
	Tools/perf-check.sh $(if $(filter command line,$(origin SAVER)),$(SAVER))

# Installs every saver. legacyScreenSaver caches loaded bundles; quitting it picks up new builds.
install: savers
	@mkdir -p "$(INSTALL_DIR)"
	@for saver in $(SAVERS); do \
		rm -rf "$(INSTALL_DIR)/Retro$$saver.saver"; \
		cp -R "$(PRODUCTS)/Release/Retro$$saver.saver" "$(INSTALL_DIR)/"; \
		echo "Installed Retro$$saver.saver"; \
	done
	@killall legacyScreenSaver 2>/dev/null || true
	@echo "Choose them in System Settings > Screen Saver."

uninstall:
	@for saver in $(SAVERS); do rm -rf "$(INSTALL_DIR)/Retro$$saver.saver"; done
	@killall legacyScreenSaver 2>/dev/null || true

# Zips every saver into one dist/RetroScreensavers.zip for a GitHub release (install.sh downloads it).
# ditto keeps the bundles and their signatures intact; the --no* flags leave out macOS metadata.
dist: savers
	@rm -rf dist
	@mkdir -p "dist/Retro Screensavers"
	@for saver in $(SAVERS); do ditto "$(PRODUCTS)/Release/Retro$$saver.saver" "dist/Retro Screensavers/Retro$$saver.saver"; done
	@ditto -c -k --keepParent --norsrc --noextattr --noacl "dist/Retro Screensavers" dist/RetroScreensavers.zip
	@rm -rf "dist/Retro Screensavers"
	@echo dist/RetroScreensavers.zip

clean:
	rm -rf $(DERIVED) $(PROJECT) dist
