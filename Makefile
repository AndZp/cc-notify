SHELL := /bin/bash

# ── Paths ──────────────────────────────────────────────────────────────────────
APP_NAME     := CCNotify
BUNDLE_ID    := sh.claude.ccnotify
INSTALL_DIR  := $(HOME)/Applications/$(APP_NAME).app
BUILD_DIR    := .build/$(APP_NAME).app

SOURCES      := $(wildcard Sources/CCNotify/*.swift)
BINARY       := $(BUILD_DIR)/Contents/MacOS/$(APP_NAME)

# ── Default target ─────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

.PHONY: help build install uninstall test clean

help:
	@echo "cc-notify — Claude Code macOS notifications"
	@echo ""
	@echo "  make install    Build, install to ~/Applications, configure Claude Code hooks"
	@echo "  make uninstall  Remove app and hooks from Claude Code settings"
	@echo "  make build      Compile only (no install)"
	@echo "  make test       Send test notifications for each event type"
	@echo "  make clean      Remove build artifacts"

# ── Build ──────────────────────────────────────────────────────────────────────
build: $(BINARY)

$(BINARY): $(SOURCES) Support/Info.plist Resources/icon.png
	@echo "▶ Compiling $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)/Contents/{MacOS,Resources}
	@swiftc -framework AppKit -framework UserNotifications \
	    $(SOURCES) \
	    -o $(BINARY)
	@cp Support/Info.plist $(BUILD_DIR)/Contents/
	@cp Resources/icon.png $(BUILD_DIR)/Contents/Resources/
	@echo "▶ Signing..."
	@codesign --force --deep --sign - $(BUILD_DIR)
	@echo "✓ Built: $(BUILD_DIR)"

# ── Install ────────────────────────────────────────────────────────────────────
install: build
	@echo "▶ Installing to $(INSTALL_DIR)..."
	@cp -r "$(BUILD_DIR)" "$(INSTALL_DIR).new"
	@rm -rf "$(INSTALL_DIR)"
	@mv "$(INSTALL_DIR).new" "$(INSTALL_DIR)"
	@# Register with Launch Services so macOS knows it's a trusted notification sender
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
	    -f "$(INSTALL_DIR)" 2>/dev/null || true
	@echo "▶ Configuring Claude Code hooks..."
	@bash Scripts/install.sh
	@echo ""
	@echo "✓ cc-notify installed! Sending test notification..."
	@sleep 1
	@$(MAKE) --no-print-directory test-stop

# ── Uninstall ──────────────────────────────────────────────────────────────────
uninstall:
	@echo "▶ Removing $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)"
	@echo "▶ Removing Claude Code hooks..."
	@bash Scripts/uninstall.sh
	@rm -f /tmp/ccnotify_*.json /tmp/ccnotify_prompt_*.ts /tmp/ccnotify-icon-*.png
	@echo "✓ cc-notify uninstalled"

# ── Test ───────────────────────────────────────────────────────────────────────
test:
	@bash Tests/test-notifications.sh

test-stop:
	@bash Tests/test-notifications.sh stop-only

# ── Clean ──────────────────────────────────────────────────────────────────────
clean:
	@rm -rf .build
	@echo "✓ Cleaned"
