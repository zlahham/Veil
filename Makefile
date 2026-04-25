APP_NAME = Veil
BUNDLE = $(APP_NAME).app
BUILD_DIR = .build
BINARY = $(BUILD_DIR)/$(APP_NAME)
BUNDLE_DIR = $(BUILD_DIR)/$(BUNDLE)
# The in-tree app bundle the developer edits/tests against.
DEV_BUNDLE = $(BUNDLE)
ENTITLEMENTS = Resources/Veil.entitlements

SWIFT = swiftc
SWIFTFLAGS = -parse-as-library \
	-target arm64-apple-macosx14.0 \
	-sdk $(shell xcrun --show-sdk-path) \
	-framework AppKit \
	-framework SwiftUI \
	-framework Carbon \
	-framework ApplicationServices \
	-framework CoreGraphics \
	-framework ServiceManagement \
	-O

SOURCES = $(shell find Sources -name '*.swift')

.PHONY: build run clean bundle install sign dev

build: $(BINARY)

$(BINARY): $(SOURCES) | $(BUILD_DIR)
	$(SWIFT) $(SWIFTFLAGS) $(SOURCES) -o $(BINARY)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

bundle: $(BINARY)
	mkdir -p "$(BUNDLE_DIR)/Contents/MacOS"
	mkdir -p "$(BUNDLE_DIR)/Contents/Resources"
	cp $(BINARY) "$(BUNDLE_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(BUNDLE_DIR)/Contents/Info.plist"
	$(MAKE) sign BUNDLE_PATH="$(BUNDLE_DIR)"
	@echo "Built $(BUNDLE_DIR)"

run: bundle
	open "$(BUNDLE_DIR)"

# Build with SPM and stage an in-tree Veil.app/ for launching.
# Re-creates the bundle scaffolding from Resources/ so the working tree
# stays clean. Ad-hoc signs to keep TCC permissions stable across rebuilds.
dev:
	swift build
	mkdir -p $(DEV_BUNDLE)/Contents/MacOS
	mkdir -p $(DEV_BUNDLE)/Contents/Resources
	cp .build/arm64-apple-macosx/debug/$(APP_NAME) $(DEV_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(DEV_BUNDLE)/Contents/Info.plist
	$(MAKE) sign BUNDLE_PATH="$(DEV_BUNDLE)"

install: dev
	pkill -x $(APP_NAME) || true
	sleep 0.5
	open $(DEV_BUNDLE)

# Ad-hoc sign a bundle. `--sign -` produces a stable signature across rebuilds
# provided bundle-id, executable path, and entitlements stay constant — which
# is what TCC keys on for Accessibility / Screen Recording grants.
sign:
	@test -n "$(BUNDLE_PATH)" || (echo "Usage: make sign BUNDLE_PATH=...app" && exit 1)
	codesign --force --sign - --entitlements $(ENTITLEMENTS) "$(BUNDLE_PATH)"
	@codesign -dv "$(BUNDLE_PATH)" 2>&1 | head -3

clean:
	rm -rf $(BUILD_DIR)
