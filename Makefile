APP_NAME := PR Pets
BUILD_DIR := .build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR ?= $(HOME)/Applications
# Set by the release workflow from the tag; local builds derive it from `git describe`.
VERSION ?=
# UNIVERSAL=1 builds for both Apple silicon and Intel and merges them with lipo.
UNIVERSAL ?= 0
ARCHITECTURES := arm64 x86_64
ifeq ($(UNIVERSAL),1)
  RELEASE_BIN_DIR := $(BUILD_DIR)/universal
else
  RELEASE_BIN_DIR := $(BUILD_DIR)/release
endif

# With only the Command Line Tools (no Xcode), SwiftPM needs the legacy build system and an explicit
# path to the Swift Testing framework. With Xcode installed these are unnecessary and left empty.
DEVELOPER_DIR := $(shell xcode-select -p 2>/dev/null)
ifneq (,$(findstring CommandLineTools,$(DEVELOPER_DIR)))
  TESTING_FRAMEWORKS := $(DEVELOPER_DIR)/Library/Developer/Frameworks
  SWIFT_FLAGS := --build-system native
  TEST_FLAGS := -Xswiftc -F$(TESTING_FRAMEWORKS) -Xlinker -F$(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_FRAMEWORKS)
endif

.PHONY: build release test app dist install uninstall run demo preview screenshots docs-images clean

build:
	swift build $(SWIFT_FLAGS)

release:
ifeq ($(UNIVERSAL),1)
	for arch in $(ARCHITECTURES); do swift build $(SWIFT_FLAGS) -c release --triple $$arch-apple-macosx14.0 || exit 1; done
	mkdir -p $(RELEASE_BIN_DIR)
	for product in PRPets pr-pets-preview; do \
	  lipo -create -output $(RELEASE_BIN_DIR)/$$product $(foreach arch,$(ARCHITECTURES),$(BUILD_DIR)/$(arch)-apple-macosx/release/$$product) || exit 1; \
	done
else
	swift build $(SWIFT_FLAGS) -c release
endif

test:
	swift test $(SWIFT_FLAGS) $(TEST_FLAGS)

app: release
	VERSION="$(VERSION)" scripts/bundle-app.sh "$(RELEASE_BIN_DIR)/PRPets" "$(APP_BUNDLE)"

# The release archive and its checksum, as uploaded to GitHub Releases.
dist: app
	rm -f $(BUILD_DIR)/PR-Pets.zip $(BUILD_DIR)/PR-Pets.zip.sha256
	cd $(BUILD_DIR) && ditto -c -k --keepParent "$(APP_NAME).app" PR-Pets.zip && shasum -a 256 PR-Pets.zip > PR-Pets.zip.sha256
	@cat $(BUILD_DIR)/PR-Pets.zip.sha256

install: app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	-osascript -e 'quit app "$(APP_NAME)"'
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

run: build
	$(BUILD_DIR)/debug/PRPets

# Runs the app against scripted fake PRs instead of GitHub.
demo: build
	PR_PETS_DATA_SOURCE=demo $(BUILD_DIR)/debug/PRPets

# Renders sprite sheets and scenario animations to ./previews for visual review.
preview: build
	$(BUILD_DIR)/debug/pr-pets-preview all previews

# Launches the real app on demo data, has it render its own windows to ./previews/app, then quits.
screenshots: build
	PR_PETS_DATA_SOURCE=demo PR_PETS_DEBUG_SNAPSHOTS=$(CURDIR)/previews/app $(BUILD_DIR)/debug/PRPets

# Refreshes the images the README uses.
docs-images: preview screenshots
	cp previews/pets.png previews/scenario-life.gif previews/scenario-kennel.gif previews/scenario-hover.gif previews/scenario-handled.gif docs/images/
	cp previews/app/pr-pets.png docs/images/dashboard.png
	cp previews/app/pet-card.png docs/images/pet-card.png

clean:
	rm -rf $(BUILD_DIR) previews
